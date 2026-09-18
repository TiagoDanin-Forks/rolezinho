defmodule RolezinhoWeb.EventEditDetailsTest do
  @moduledoc """
  The single "Detalhes do rolê" card on the admin event edit page collects
  every text/textarea/date field for an event — title, description, local,
  date, time, price, Pix key, password, slug — and saves them with one
  button.

  Rules under test:
    * All fields live in the same `#details-form`.
    * A single click of "Salvar" persists every changed field atomically.
    * Slug rename goes through `rename_slug/2` (with its redirect + move
      semantics) *and* the rest of the fields still save on the same click.
    * The Pix key input keeps the password-manager ignore attributes.
    * The attendee list is not editable from this form.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Event.Meta
  alias Rolezinho.Events

  defp create_event(attrs) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "ee-#{System.unique_integer([:positive])}",
      "description" => "",
      "local" => "Rua Caripunas",
      "date" => "2026-08-15",
      "time" => "19:00",
      "main_size" => "3",
      "wait_size" => "0",
      "password" => "",
      "price" => "15",
      "pix_key" => "9199999999"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs), admin?: true)
    event
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  # The five inputs are all in the same form; helper to build the params map.
  defp details_params(overrides) do
    defaults = %{
      "title" => "Vôlei",
      "description" => "",
      "local" => "Rua Caripunas",
      "date" => "2026-08-15",
      "time" => "19:00",
      "price" => "15",
      "pix_key" => "9199999999",
      "password" => "",
      "slug" => "same"
    }

    %{"details" => Map.merge(defaults, overrides)}
  end

  describe "form layout" do
    setup %{conn: conn} do
      event = create_event(%{"title" => "Original"})
      {:ok, view, html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")
      %{view: view, html: html, event: event}
    end

    test "every text/textarea/date field lives in one #details-form", %{view: view} do
      for name <- ~w(title description local date time price pix_key password slug) do
        assert has_element?(view, "#details-form [name='details[#{name}]']"),
               "expected #details-form to carry a control for #{name}"
      end
    end

    test "there is exactly one save button on the form", %{view: view, html: html} do
      # Count `<button type="submit">` inside the form. Also assert its label.
      matches = Regex.scan(~r|<button[^>]*type="submit"[^>]*>([^<]+)</button>|, html)
      submits_in_form = view |> element("#details-form button[type='submit']") |> render()

      assert submits_in_form =~ "Salvar"
      # Only one submit button in the form itself.
      assert length(Enum.filter(matches, fn [_, label] -> String.trim(label) =~ "Salvar" end)) >=
               1
    end

    test "the old per-section forms are gone", %{view: view} do
      # A regression here would mean I split the card back apart accidentally.
      refute has_element?(view, "#meta-form")
      refute has_element?(view, "#payment-form")
      refute has_element?(view, "#password-form")
      refute has_element?(view, "#slug-form")
      refute has_element?(view, "#raw-edit-form")
    end

    test "the inputs are pre-filled with the current values", %{event: event} = ctx do
      # Round-trip check: whatever we seeded shows up in each field.
      {:ok, _view, html} = live(admin_conn(ctx.conn), ~p"/admin/r/#{event.slug}/edit")

      assert html =~ ~s(name="details[title]") and html =~ ~s(value="Original")
      assert html =~ ~s(name="details[local]") and html =~ ~s(value="Rua Caripunas")
      assert html =~ ~s(name="details[date]") and html =~ ~s(value="2026-08-15")
      assert html =~ ~s(name="details[time]") and html =~ ~s(value="19:00")
      assert html =~ ~s(name="details[price]") and html =~ ~s(value="15")
      assert html =~ ~s(name="details[pix_key]") and html =~ ~s(value="9199999999")
      assert html =~ ~s(name="details[slug]") and html =~ ~s(value="#{event.slug}")
    end
  end

  describe "single-button save" do
    test "persists title, description, meta, payment and password in one click",
         %{conn: conn} do
      event = create_event(%{"title" => "Antes"})

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      view
      |> form(
        "#details-form",
        details_params(%{
          "title" => "Depois",
          "description" => "Recado novo",
          "local" => "Praia Nova",
          "date" => "2027-01-05",
          "time" => "20:30",
          "price" => "22,50",
          "pix_key" => "novo@example.com",
          "password" => "SEGREDO",
          "slug" => event.slug
        })
      )
      |> render_submit()

      reloaded = Events.find(event.slug)
      {meta, description} = Meta.extract(reloaded.header)

      assert reloaded.title == "Depois"
      assert description == "Recado novo"
      assert meta.local == "Praia Nova"
      assert meta.date == ~D[2027-01-05]
      assert meta.time == ~T[20:30:00]
      assert reloaded.price_cents == 2250
      assert reloaded.pix_key == "novo@example.com"
      assert reloaded.password == "SEGREDO"
    end

    test "empty password clears it, empty price and pix wipe them", %{conn: conn} do
      event = create_event(%{"password" => "old", "price" => "10", "pix_key" => "x@y"})

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      view
      |> form(
        "#details-form",
        details_params(%{"password" => "", "price" => "", "pix_key" => "", "slug" => event.slug})
      )
      |> render_submit()

      reloaded = Events.find(event.slug)
      assert reloaded.password == nil
      assert reloaded.price_cents == nil
      assert reloaded.pix_key == nil
    end

    test "empty title is rejected and none of the other fields commit", %{conn: conn} do
      event = create_event(%{"title" => "Válido", "local" => "Antes"})

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      html =
        view
        |> form(
          "#details-form",
          details_params(%{
            "title" => "   ",
            "local" => "Depois — não deve gravar",
            "slug" => event.slug
          })
        )
        |> render_submit()

      assert html =~ "Não deu pra salvar"

      reloaded = Events.find(event.slug)
      assert reloaded.title == "Válido"
      {meta, _} = Meta.extract(reloaded.header)
      # Local was not written either — the whole changeset was rejected.
      assert meta.local == "Antes"
    end

    test "the attendee list survives an unrelated edit", %{conn: conn} do
      event = create_event(%{})
      {:ok, event} = Events.add_to_main(event, "Alice")

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      view
      |> form(
        "#details-form",
        details_params(%{"description" => "novo texto", "slug" => event.slug})
      )
      |> render_submit()

      reloaded = Events.find(event.slug)
      assert [%{name: "Alice"} | _] = reloaded.main_list
      assert reloaded.main_capacity == 3
    end
  end

  describe "slug rename via the same form" do
    test "changing the slug renames the event AND commits the other changes",
         %{conn: conn} do
      event = create_event(%{"title" => "Antes"})
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      # The submit redirects to the new admin edit URL.
      {:error, {:live_redirect, %{to: to}}} =
        view
        |> form(
          "#details-form",
          details_params(%{
            "slug" => "novo-slug",
            "title" => "Depois",
            "description" => "com novo slug"
          })
        )
        |> render_submit()

      assert to == "/admin/r/novo-slug/edit"

      # Old slug is gone, new slug exists, and the bulk changes stuck.
      assert is_nil(Events.find(event.slug))
      moved = Events.find("novo-slug")
      assert moved.title == "Depois"
      {_meta, description} = Meta.extract(moved.header)
      assert description == "com novo slug"
    end

    test "a taken slug flashes an error and does NOT commit the other changes",
         %{conn: conn} do
      taken = create_event(%{"slug" => "tomado"})
      event = create_event(%{"title" => "Ainda o mesmo"})

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      html =
        view
        |> form(
          "#details-form",
          details_params(%{
            "slug" => taken.slug,
            "title" => "Não deveria gravar"
          })
        )
        |> render_submit()

      assert html =~ "já está em uso"
      reloaded = Events.find(event.slug)
      # Title stayed the original because slug rename aborted the whole flow.
      assert reloaded.title == "Ainda o mesmo"
    end

    test "a malformed slug is rejected with a clear message", %{conn: conn} do
      event = create_event(%{})
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      # Bypass the HTML5 pattern by submitting the form struct directly.
      html =
        render_submit(
          form(view, "#details-form"),
          details_params(%{"slug" => "não vale"})
        )

      assert html =~ "Slug inválido"
    end
  end

  describe "auto-retag slug when the date changes" do
    # These tests exercise the "URL follows the date" behaviour: when the user
    # picks a new date and did not touch the slug themselves, and the slug
    # ends with the current `-DD-MM` (with an optional `-clonado` tail), we
    # rewrite the slug to end with the new `-DD-MM`. Any other case, the slug
    # is left exactly as the user submitted.

    defp seed_with_slug_and_date(conn, slug, date_iso, extra \\ %{}) do
      event =
        create_event(
          Map.merge(
            %{
              "slug" => slug,
              "title" => "Rolê",
              "date" => date_iso
            },
            extra
          )
        )

      # Sanity check: the event actually got stored with the date we asked
      # for — otherwise the retag tests would silently no-op.
      {meta, _} = Meta.extract(event.header)
      assert meta.date == Date.from_iso8601!(date_iso)

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")
      {view, event}
    end

    test "-DD-MM suffix is rewritten when the date changes and the slug wasn't touched",
         %{conn: conn} do
      {view, event} = seed_with_slug_and_date(conn, "meu-rolezinho-18-09", "2026-09-18")

      {:error, {:live_redirect, %{to: to}}} =
        view
        |> form(
          "#details-form",
          details_params(%{"slug" => event.slug, "date" => "2026-09-22"})
        )
        |> render_submit()

      assert to == "/admin/r/meu-rolezinho-22-09/edit"
      assert Events.find("meu-rolezinho-22-09")
      assert is_nil(Events.find("meu-rolezinho-18-09"))
    end

    test "-DD-MM-clonado suffix is rewritten too", %{conn: conn} do
      {view, event} = seed_with_slug_and_date(conn, "meu-rolezinho-18-09-clonado", "2026-09-18")

      {:error, {:live_redirect, %{to: to}}} =
        view
        |> form(
          "#details-form",
          details_params(%{"slug" => event.slug, "date" => "2026-09-22"})
        )
        |> render_submit()

      assert to == "/admin/r/meu-rolezinho-22-09-clonado/edit"
      assert Events.find("meu-rolezinho-22-09-clonado")
    end

    test "a manually-changed slug beats the auto-retag", %{conn: conn} do
      {view, _event} = seed_with_slug_and_date(conn, "meu-rolezinho-18-09", "2026-09-18")

      {:error, {:live_redirect, %{to: to}}} =
        view
        |> form(
          "#details-form",
          details_params(%{"slug" => "escolha-do-usuario", "date" => "2026-09-22"})
        )
        |> render_submit()

      # The user's slug wins; no `-22-09` involved.
      assert to == "/admin/r/escolha-do-usuario/edit"
    end

    test "a slug without the date pattern is left alone", %{conn: conn} do
      {view, event} = seed_with_slug_and_date(conn, "sem-tag-de-data", "2026-09-18")

      view
      |> form(
        "#details-form",
        details_params(%{"slug" => event.slug, "date" => "2026-09-22"})
      )
      |> render_submit()

      # No redirect — the slug did not change. The event is still reachable
      # under the original URL, and the date did move.
      assert Events.find("sem-tag-de-data")
      reloaded = Events.find("sem-tag-de-data")
      {meta, _} = Meta.extract(reloaded.header)
      assert meta.date == ~D[2026-09-22]
    end

    test "a -DD-MM pattern that doesn't match the current date is left alone",
         %{conn: conn} do
      # Slug says 05-05 but the actual event date is 18-09. That's not a
      # date tag we manage — keep it as is.
      {view, event} = seed_with_slug_and_date(conn, "mensagem-do-05-05", "2026-09-18")

      view
      |> form(
        "#details-form",
        details_params(%{"slug" => event.slug, "date" => "2026-09-22"})
      )
      |> render_submit()

      assert Events.find("mensagem-do-05-05")
      refute Events.find("mensagem-do-22-09")
    end

    test "no retag when the original event had no date", %{conn: conn} do
      # Slug ends in something that looks like `-DD-MM`, but the event had no
      # date stored, so we cannot know if the tail is a date tag we own —
      # leave the slug alone.
      event =
        create_event(%{
          "slug" => "tag-parecida-com-data-01-02",
          "title" => "Rolê",
          "date" => ""
        })

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      view
      |> form(
        "#details-form",
        details_params(%{"slug" => event.slug, "date" => "2026-09-22"})
      )
      |> render_submit()

      assert Events.find("tag-parecida-com-data-01-02")
    end

    test "no retag when the user clears the date", %{conn: conn} do
      {view, event} = seed_with_slug_and_date(conn, "meu-rolezinho-18-09", "2026-09-18")

      view
      |> form(
        "#details-form",
        details_params(%{"slug" => event.slug, "date" => ""})
      )
      |> render_submit()

      # We don't strip the tag — that's up to the user. The URL stays.
      assert Events.find("meu-rolezinho-18-09")
    end

    test "no retag when the date did not actually change", %{conn: conn} do
      {view, event} = seed_with_slug_and_date(conn, "meu-rolezinho-18-09", "2026-09-18")

      view
      |> form(
        "#details-form",
        details_params(%{"slug" => event.slug, "date" => "2026-09-18"})
      )
      |> render_submit()

      # Same date, same slug — no redirect and the event stays at the same URL.
      assert Events.find("meu-rolezinho-18-09")
    end
  end

  describe "live slug retag on `phx-change`" do
    # These tests exercise the live behaviour: as soon as the user edits the
    # date, the slug field must update in the same round trip (no submit
    # needed) AND a `slug-retagged` event must be pushed to the client so the
    # accent-flash animation can play. The rules about "who wins" (user vs.
    # server retag) are identical to the submit-time rules; the difference is
    # the timing.

    defp render_change_target(view, _form_id, target, params) do
      # `render_change/2` needs the full form payload with a `_target`.
      # Wrap so tests stay readable.
      render_change(view, "validate_details", %{"_target" => target, "details" => params})
    end

    defp full_details(overrides) do
      Map.merge(
        %{
          "title" => "Rolê",
          "description" => "",
          "local" => "",
          "date" => "2026-09-18",
          "time" => "",
          "price" => "",
          "pix_key" => "",
          "password" => "",
          "slug" => "meu-rolezinho-18-09"
        },
        overrides
      )
    end

    test "editing the date field updates the slug value in the same round trip",
         %{conn: conn} do
      event =
        create_event(%{"slug" => "meu-rolezinho-18-09", "date" => "2026-09-18"})

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      html =
        render_change_target(
          view,
          "details-form",
          ["details", "date"],
          full_details(%{"date" => "2026-09-22", "slug" => event.slug})
        )

      # The slug input's rendered value is the retagged one — no submit yet.
      assert html =~ ~s(name="details[slug]") and html =~ ~s(value="meu-rolezinho-22-09")
      # And the DB still has the old slug because we did not save.
      assert Events.find("meu-rolezinho-18-09")
      refute Events.find("meu-rolezinho-22-09")
    end

    test "a `slug-retagged` event is pushed to the client on a live retag",
         %{conn: conn} do
      event = create_event(%{"slug" => "meu-rolezinho-18-09", "date" => "2026-09-18"})
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      render_change_target(
        view,
        "details-form",
        ["details", "date"],
        full_details(%{"date" => "2026-09-22", "slug" => event.slug})
      )

      # `push_event` from the server ends up on the LV process's mailbox in
      # tests. `assert_push_event/3` is the LiveViewTest helper for it.
      assert_push_event(view, "slug-retagged", %{slug: "meu-rolezinho-22-09"})
    end

    test "editing the date twice retags each time (uses the moving reference date)",
         %{conn: conn} do
      event = create_event(%{"slug" => "meu-rolezinho-18-09", "date" => "2026-09-18"})
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      # First date change: -18-09 -> -22-09
      render_change_target(
        view,
        "details-form",
        ["details", "date"],
        full_details(%{"date" => "2026-09-22", "slug" => "meu-rolezinho-18-09"})
      )

      assert_push_event(view, "slug-retagged", %{slug: "meu-rolezinho-22-09"})

      # Second date change: the client sends the already-retagged slug in the
      # form payload; we should retag again -22-09 -> -25-09.
      html =
        render_change_target(
          view,
          "details-form",
          ["details", "date"],
          full_details(%{"date" => "2026-09-25", "slug" => "meu-rolezinho-22-09"})
        )

      assert_push_event(view, "slug-retagged", %{slug: "meu-rolezinho-25-09"})
      assert html =~ ~s(value="meu-rolezinho-25-09")
    end

    test "the -clonado tail is preserved on a live retag", %{conn: conn} do
      event =
        create_event(%{
          "slug" => "meu-rolezinho-18-09-clonado",
          "date" => "2026-09-18"
        })

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      render_change_target(
        view,
        "details-form",
        ["details", "date"],
        full_details(%{
          "date" => "2026-09-22",
          "slug" => "meu-rolezinho-18-09-clonado"
        })
      )

      assert_push_event(view, "slug-retagged", %{slug: "meu-rolezinho-22-09-clonado"})
    end

    test "editing the slug directly disables auto-retag for the rest of the session",
         %{conn: conn} do
      event = create_event(%{"slug" => "meu-rolezinho-18-09", "date" => "2026-09-18"})
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      # User types in the slug field — sets `slug_touched?: true`.
      render_change_target(
        view,
        "details-form",
        ["details", "slug"],
        full_details(%{"slug" => "escolha-do-usuario"})
      )

      # Now edit the date. Retag must NOT fire, and no push_event either.
      html =
        render_change_target(
          view,
          "details-form",
          ["details", "date"],
          full_details(%{"slug" => "escolha-do-usuario", "date" => "2026-09-22"})
        )

      assert html =~ ~s(value="escolha-do-usuario")
      refute_push_event(view, "slug-retagged", _payload)
    end

    test "editing an unrelated field is a passthrough (no retag, no push_event)",
         %{conn: conn} do
      event = create_event(%{"slug" => "meu-rolezinho-18-09", "date" => "2026-09-18"})
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      render_change_target(
        view,
        "details-form",
        ["details", "title"],
        full_details(%{"title" => "Novo Título", "slug" => event.slug})
      )

      refute_push_event(view, "slug-retagged", _payload)
    end

    test "a slug without the date pattern is left alone on a live date change",
         %{conn: conn} do
      event = create_event(%{"slug" => "sem-tag-de-data", "date" => "2026-09-18"})
      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      html =
        render_change_target(
          view,
          "details-form",
          ["details", "date"],
          full_details(%{"slug" => "sem-tag-de-data", "date" => "2026-09-22"})
        )

      assert html =~ ~s(value="sem-tag-de-data")
      refute_push_event(view, "slug-retagged", _payload)
    end

    test "the animation utility is loaded via the app stylesheet" do
      # Sanity check that the class the hook toggles exists in the stylesheet
      # — without this, the fanciness would silently be nothing.
      css = File.read!("priv/static/assets/css/app.css")
      assert css =~ ".animate-flash-accent", "expected the animation class in the built CSS"
      assert css =~ "@keyframes rolezinho-flash-accent"
    end
  end

  describe "Pix key still opts out of password managers" do
    test "carries every ignore attribute", %{conn: conn} do
      event = create_event(%{})
      {:ok, _view, html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      pix_input =
        Regex.run(~r|<input[^>]*name="details\[pix_key\]"[^>]*>|, html)
        |> List.first()

      assert pix_input, "expected a Pix key input on the edit page"

      for attr <- [
            ~s(autocomplete="off"),
            ~s(data-1p-ignore="true"),
            ~s(data-lpignore="true"),
            ~s(data-bwignore="true"),
            ~s(data-form-type="other")
          ] do
        assert pix_input =~ attr,
               "expected the Pix key input to include #{attr}, got: #{pix_input}"
      end
    end
  end
end

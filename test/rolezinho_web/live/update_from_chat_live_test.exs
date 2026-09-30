defmodule RolezinhoWeb.UpdateFromChatLiveTest do
  @moduledoc """
  End-to-end coverage for `/atualizar` — the URL-driven bulk update
  surface an LLM points a human at.

  Two flows:

    * **picker** at `/atualizar` — we render the caller's updatable
      events; picking one navigates to `/atualizar/:slug` with the
      LLM params preserved.
    * **diff** at `/atualizar/:slug` — slug resolves, the two-column
      view renders, the human confirms, the DB reflects the changes.

  Anonymous visitors get bounced to `/entrar` with `return_to` set,
  so an LLM link they clicked before signing in still reaches its
  destination after auth.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Events

  defp register do
    # Pad to guarantee >= 6 chars (username min length), so tests
    # don't intermittently fail when `unique_integer` returns a
    # single-digit value — "chat4" is 5 chars and would be rejected.
    n = System.unique_integer([:positive]) |> Integer.to_string() |> String.pad_leading(4, "0")

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "chat#{n}",
        "password" => "supersecret"
      })

    user
  end

  defp signed_in(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
  end

  defp create_event(user, overrides \\ %{}) do
    n = System.unique_integer([:positive])

    defaults = %{
      "title" => "Vôlei",
      "slug" => "chatv-#{n}",
      "main_size" => "4",
      "wait_size" => "0"
    }

    {:ok, event} =
      Events.create(Map.merge(defaults, overrides), created_by_user_id: user.id)

    event
  end

  describe "anonymous access" do
    test "bounces to /entrar with return_to preserved", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: to}}} =
               live(conn, ~p"/atualizar?names[0]=Alice")

      assert String.starts_with?(to, "/entrar?")
      assert to =~ "return_to=%2Fatualizar"
      # The names[0]=Alice bit survives the round trip (percent-encoded
      # inside return_to).
      assert to =~ "names"
    end
  end

  describe "picker" do
    test "shows the user's updatable events when no `event` param",
         %{conn: conn} do
      user = register()
      event = create_event(user)
      conn = signed_in(conn, user)

      {:ok, view, html} = live(conn, ~p"/atualizar")

      assert html =~ "Atualizar rolezinho"
      assert has_element?(view, "a", event.title)
    end

    test "empty state when the user has no updatable events", %{conn: conn} do
      user = register()
      conn = signed_in(conn, user)

      {:ok, _view, html} = live(conn, ~p"/atualizar")
      assert html =~ "Você não tem rolês"
    end

    test "picker link binds slug into the path and preserves LLM query params",
         %{conn: conn} do
      user = register()
      event = create_event(user)
      conn = signed_in(conn, user)

      {:ok, view, _html} = live(conn, ~p"/atualizar?names[0]=Alice&checks[0]=1")

      # The picker row's href puts the slug in the path
      # (`/atualizar/:slug`) and keeps the LLM proposal in the query.
      # This is the invariant that guarantees the LLM's URL contract
      # stays event-agnostic — the slug lives in the routing layer,
      # never in the query the LLM built.
      assert has_element?(view, ~s(a[href^="/atualizar/#{event.slug}?"][href*="names"]))
    end

    test "a `/atualizar/:slug` the caller cannot update falls back to the picker",
         %{conn: conn} do
      owner = register()
      other = register()
      event = create_event(owner)
      conn = signed_in(conn, other)

      {:ok, _view, html} = live(conn, ~p"/atualizar/#{event.slug}")

      # Falls back to the picker (empty for `other`).
      assert html =~ "Você não tem rolês"
    end

    test "encoded=<base64> is expanded before rendering the picker link",
         %{conn: conn} do
      user = register()
      event = create_event(user)
      conn = signed_in(conn, user)

      # LLM sent everything through the base64 shortcut. When the
      # human picks an event, the resulting link must carry the
      # decoded, human-readable query — not the opaque blob — so a
      # copy-paste from the address bar is inspectable and the diff
      # URL is a normal `/atualizar/:slug?names[0]=...`.
      encoded = Base.url_encode64("names[0]=Alice&checks[0]=1")
      {:ok, view, _html} = live(conn, ~p"/atualizar?encoded=#{encoded}")

      assert has_element?(
               view,
               ~s(a[href^="/atualizar/#{event.slug}?"][href*="names"])
             )

      # And the blob itself is gone from the picker href.
      refute render(view) =~ "encoded="
    end

    # Regression: the picker link used to be a live `patch`, which
    # crashed on the picker → diff transition because it fires
    # `handle_params/3` (undefined here) and crosses live_actions.
    # `navigate` is the right primitive — the two views load
    # completely different assign sets, so a clean re-mount is
    # correct. Verify it by walking the link end-to-end.
    test "clicking a picker link lands on the diff view without crashing",
         %{conn: conn} do
      user = register()
      event = create_event(user)
      conn = signed_in(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/atualizar?names[0]=Alice&checks[0]=1")

      # `follow_redirect/2` traverses a `live_redirect` (navigate)
      # and mounts the target LV; if the picker used `patch`, the
      # crash would surface here.
      {:ok, diff_view, diff_html} =
        view
        |> element(~s(a[href^="/atualizar/#{event.slug}?"]))
        |> render_click()
        |> follow_redirect(conn)

      # We reached the diff view: the LLM's Alice is pre-filled on
      # the right column, and the Confirmar form is present.
      assert diff_html =~ "Editando"
      assert diff_html =~ ~s(value="Alice")
      assert has_element?(diff_view, "#confirm-form")
    end

    # End-to-end sanity for the compact-alias combo. This is the
    # "real-world" URL shape the docs recommend; the parser tests
    # cover equivalence at the pure-function layer, this one proves
    # the whole stack (picker → diff → confirm → DB) works with it.
    test "compact aliases (n=, c=, k=) flow through picker to a persisted update",
         %{conn: conn} do
      user = register()
      event = create_event(user, %{"main_size" => "4"})
      conn = signed_in(conn, user)

      # Compact form: 3 names, 2 marked paid, capacity bumped to 5.
      {:ok, view, _html} =
        live(conn, ~p"/atualizar?n=Alice|Bruno|Carla&c=1-1&k=5")

      # The picker's href passes the compact form through untouched
      # (expanding would defeat the whole point of the shorts).
      assert has_element?(view, ~s(a[href^="/atualizar/#{event.slug}?"][href*="n="]))

      # Follow into the diff view.
      {:ok, diff_view, diff_html} =
        view
        |> element(~s(a[href^="/atualizar/#{event.slug}?"]))
        |> render_click()
        |> follow_redirect(conn)

      # All three names pre-filled on the depois column.
      assert diff_html =~ ~s(value="Alice")
      assert diff_html =~ ~s(value="Bruno")
      assert diff_html =~ ~s(value="Carla")

      # Capacity input bumped to 5 per `k=5`.
      assert has_element?(diff_view, ~s(input[name="capacity"][value="5"]))

      # Confirm and check the DB.
      diff_view |> form("#confirm-form") |> render_submit()

      reloaded = Events.find(event.slug)
      assert reloaded.main_capacity == 5
      names = reloaded.main_list |> Enum.map(& &1.name) |> Enum.filter(&(&1 != ""))
      assert names == ["Alice", "Bruno", "Carla"]

      # `c=1-1` — slots 0 and 2 paid, slot 1 (Bruno) unspecified
      # (which for a brand-new row defaults to false).
      [alice, bruno, carla | _] = reloaded.main_list
      assert alice.paid == true
      assert bruno.paid == false
      assert carla.paid == true
    end
  end

  describe "diff view" do
    setup %{conn: conn} do
      user = register()
      event = create_event(user)
      {:ok, event, _} = Events.add_party(event, "Bruno", 1, participant_id: "tok-bruno")

      %{conn: signed_in(conn, user), user: user, event: event}
    end

    test "renders both columns with the LLM proposal on the right",
         %{conn: conn, event: event} do
      params = %{"names" => %{"0" => "Alice"}, "checks" => %{"0" => "1"}}
      {:ok, _view, html} = live(conn, ~p"/atualizar/#{event.slug}?#{params}")

      # Left (antes) shows Bruno at slot 1.
      assert html =~ "Bruno"
      # Right (depois) has an input pre-filled with Alice.
      assert html =~ ~s(value="Alice")
      # Paid checkbox for row 1 is checked (`checks[0]=1` → slot 1).
      assert html =~ ~s(name="main[1][paid]") and html =~ ~s(checked)
    end

    test "confirm submits the form and applies the update",
         %{conn: conn, event: event} do
      params = %{"names" => %{"0" => "Alice"}, "checks" => %{"0" => "1"}}
      {:ok, view, _html} = live(conn, ~p"/atualizar/#{event.slug}?#{params}")

      # Simulate what a click on "Confirmar" would send: the whole
      # form with LLM defaults intact. `render_submit/2` on the form
      # serialises the current input values.
      assert {:error, {:live_redirect, %{to: to}}} =
               view
               |> form("#confirm-form")
               |> render_submit()

      assert to == "/r/#{event.slug}"

      reloaded = Events.find(event.slug)
      [first | _] = reloaded.main_list
      assert first.name == "Alice"
      assert first.paid == true
      # Different name → identity dropped (Bruno's participant_id gone).
      assert first.participant_id == nil
    end

    test "new field chips render and can be discarded",
         %{conn: conn, event: event} do
      params = %{
        "names" => %{"0" => "Alice"},
        "fields" => %{"0" => %{"tamanho" => "M"}}
      }

      {:ok, view, html} = live(conn, ~p"/atualizar/#{event.slug}?#{params}")

      # New-field chip is present.
      assert html =~ "Campos novos"
      assert has_element?(view, ~s(button[phx-click="discard_field"][phx-value-key="tamanho"]))

      # Discard it.
      view
      |> element(~s(button[phx-click="discard_field"][phx-value-key="tamanho"]))
      |> render_click()

      html = render(view)
      # Chip is gone — and so are the per-row inputs that were
      # rendered for the pending field.
      refute has_element?(view, ~s(button[phx-click="discard_field"][phx-value-key="tamanho"]))
      refute html =~ ~s(name="main[1][values][tamanho]")
    end

    test "confirming with a new-field chip creates the field on the event",
         %{conn: conn, event: event} do
      params = %{
        "names" => %{"0" => "Alice"},
        "fields" => %{"0" => %{"tamanho" => "M"}}
      }

      {:ok, view, _html} = live(conn, ~p"/atualizar/#{event.slug}?#{params}")

      view
      |> form("#confirm-form")
      |> render_submit()

      reloaded = Events.find(event.slug)
      # Field exists.
      assert Enum.any?(reloaded.form_fields, &(&1.id == "tamanho"))
      # Alice's row carries the value.
      [first | _] = reloaded.main_list
      assert first.name == "Alice"
      assert Map.get(first.values, "tamanho") == "M"
    end

    test "field_labels[<key>] carries through to the created field's label",
         %{conn: conn, event: event} do
      params = %{
        "names" => %{"0" => "Alice"},
        "fields" => %{"0" => %{"nome-na-camisa" => "Alice A."}},
        "field_labels" => %{"nome-na-camisa" => "Nome na camisa"}
      }

      {:ok, view, html} = live(conn, ~p"/atualizar/#{event.slug}?#{params}")

      # Chip shows the human-cased label, not the humanized slug
      # ("Nome Na Camisa").
      assert html =~ "Nome na camisa"
      refute html =~ "Nome Na Camisa"

      view
      |> form("#confirm-form")
      |> render_submit()

      reloaded = Events.find(event.slug)
      field = Enum.find(reloaded.form_fields, &(&1.id == "nome-na-camisa"))
      # Field created with the LLM-supplied label, casing preserved.
      assert field.label == "Nome na camisa"
    end
  end

  describe "capacity" do
    setup %{conn: conn} do
      user = register()
      event = create_event(user, %{"main_size" => "4"})
      %{conn: signed_in(conn, user), event: event}
    end

    test "the diff header renders the capacity input pre-filled",
         %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/atualizar/#{event.slug}?capacity=6")

      # Input is present and pre-filled with 6, and the "antes"
      # badge shows the current capacity (4) so the change is
      # visible before submit.
      assert has_element?(view, ~s(input[name="capacity"][value="6"]))
      assert render(view) =~ "antes: 4"
    end

    test "submitting the form applies the new capacity",
         %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/atualizar/#{event.slug}?capacity=6")

      view
      |> form("#confirm-form")
      |> render_submit()

      reloaded = Events.find(event.slug)
      assert reloaded.main_capacity == 6
    end

    test "URL name at a slot past current capacity grows implicitly",
         %{conn: conn, event: event} do
      # Slot 5 (0-based 4) is past the event's capacity of 4.
      params = %{"names" => %{"4" => "Ester"}}
      {:ok, view, _html} = live(conn, ~p"/atualizar/#{event.slug}?#{params}")

      # Header capacity input auto-bumps to fit.
      assert has_element?(view, ~s(input[name="capacity"][value="5"]))

      view
      |> form("#confirm-form")
      |> render_submit()

      reloaded = Events.find(event.slug)
      assert reloaded.main_capacity == 5
      assert Enum.at(reloaded.main_list, 4).name == "Ester"
    end
  end

  describe "wait custom fields" do
    setup %{conn: conn} do
      user = register()

      event =
        create_event(user, %{"main_size" => "2", "wait_size" => "3"})

      {:ok, event} = Events.add_form_field(event, %{"label" => "Tamanho"})
      {:ok, event} = Events.add_to_wait(event, "Ana", participant_id: "tok-ana")

      %{conn: signed_in(conn, user), event: event}
    end

    test "wait_fields values render on the wait depois column",
         %{conn: conn, event: event} do
      params = %{
        "wait_names" => %{"0" => "Ana"},
        "wait_fields" => %{"0" => %{"tamanho" => "P"}}
      }

      {:ok, view, _html} = live(conn, ~p"/atualizar/#{event.slug}?#{params}")

      # The wait scope's field input exists and is pre-filled.
      assert has_element?(
               view,
               ~s(input[name="wait[1][values][tamanho]"][value="P"])
             )
    end

    test "confirm persists the wait-row's custom-field value",
         %{conn: conn, event: event} do
      params = %{
        "wait_names" => %{"0" => "Ana"},
        "wait_fields" => %{"0" => %{"tamanho" => "P"}}
      }

      {:ok, view, _html} = live(conn, ~p"/atualizar/#{event.slug}?#{params}")

      view
      |> form("#confirm-form")
      |> render_submit()

      reloaded = Events.find(event.slug)
      [wait_first | _] = reloaded.wait_list
      assert wait_first.name == "Ana"
      assert Map.get(wait_first.values, "tamanho") == "P"
    end
  end
end

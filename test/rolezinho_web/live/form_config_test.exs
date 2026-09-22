defmodule RolezinhoWeb.FormConfigTest do
  @moduledoc """
  RN-60, RN-61 and RN-62 end to end: the organizer configures a question, it
  shows up in the join form, and the answer lands on that person's row without
  ever appearing in the public list.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp seed(attrs \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei-form-#{System.unique_integer([:positive])}",
      "description" => "End: Praia",
      "main_size" => "6",
      "wait_size" => "2"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  defp as_admin(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  defp answers(slug, name) do
    Events.find(slug).main_list
    |> Enum.find(&(&1.name == name))
    |> Map.get(:values)
  end

  describe "the default form (RN-61)" do
    test "asks for a name and nothing else" do
      event = seed()

      fields = Events.form_fields(event)

      assert [%{id: "name", required: true, locked: true}] = fields
    end

    test "an event that predates custom forms still asks for a name" do
      event = seed()

      assert event.form_fields == []
      assert length(Events.form_fields(event)) == 1
    end
  end

  describe "the name field (RN-60)" do
    test "cannot be removed" do
      event = seed()

      assert {:error, :locked_field} = Events.remove_form_field(event, "name")
    end

    test "cannot be made optional" do
      event = seed()

      assert {:error, :locked_field} = Events.toggle_form_field_required(event, "name")
    end
  end

  describe "adding a question" do
    test "appears in the form with an id derived from the label" do
      event = seed()

      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa (P/M/G)"})

      assert %{id: "camisa-p-m-g", label: "Camisa (P/M/G)"} =
               Events.form_fields(event) |> Enum.find(&(&1.label == "Camisa (P/M/G)"))
    end

    test "keeps ids unique when two labels collide" do
      event = seed()

      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa"})
      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa"})

      ids = Events.form_fields(event) |> Enum.map(& &1.id)
      assert length(Enum.uniq(ids)) == length(ids)
    end

    test "refuses an empty label" do
      event = seed()

      assert {:error, :empty_label} = Events.add_form_field(event, %{"label" => "   "})
    end

    test "refuses a type nobody offers" do
      event = seed()

      assert {:error, :invalid_type} =
               Events.add_form_field(event, %{"label" => "X", "type" => "password"})
    end

    test "stops before the form becomes a survey" do
      event = seed()

      event =
        Enum.reduce(1..7, event, fn n, acc ->
          {:ok, acc} = Events.add_form_field(acc, %{"label" => "Campo #{n}"})
          acc
        end)

      assert {:error, :too_many_fields} = Events.add_form_field(event, %{"label" => "Mais um"})
    end

    test "survives a later save of the event" do
      event = seed()
      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa"})

      # A save rebuilds the event from its struct; a field missing from that map
      # would be silently dropped here.
      {:ok, _} = Events.add_to_main(event, "Márcia", participant_id: "abc")

      assert Events.find(event.slug) |> Events.form_fields() |> length() == 2
    end
  end

  describe "renaming a question" do
    test "changes the label and keeps the id stable" do
      event = seed()
      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa"})

      assert {:ok, event} = Events.rename_form_field(event, "camisa", "Tamanho da camisa")

      camisa = Enum.find(Events.form_fields(event), &(&1.id == "camisa"))
      assert camisa.label == "Tamanho da camisa"
      # The id is what keeps stored answers reachable — it must not move.
      assert camisa.id == "camisa"
    end

    test "trims the new label before saving" do
      event = seed()
      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa"})

      assert {:ok, event} = Events.rename_form_field(event, "camisa", "  Tamanho  ")

      camisa = Enum.find(Events.form_fields(event), &(&1.id == "camisa"))
      assert camisa.label == "Tamanho"
    end

    test "the answer stored under the old label survives the rename" do
      # This is the invariant the id-immutability rule defends: renaming the
      # label must not orphan any attendee's answer.
      event = seed()
      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa"})

      {:ok, event} =
        Events.add_to_main(event, "Márcia",
          participant_id: "tok",
          values: %{"camisa" => "G"}
        )

      assert {:ok, _event} = Events.rename_form_field(event, "camisa", "Tamanho")

      row = Events.find(event.slug).main_list |> List.first()
      assert row.values == %{"camisa" => "G"}
    end

    test "refuses a blank label" do
      event = seed()
      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa"})

      assert {:error, :empty_label} = Events.rename_form_field(event, "camisa", "   ")
    end

    test "refuses a label over 40 chars" do
      event = seed()
      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa"})
      too_long = String.duplicate("a", 41)

      assert {:error, :label_too_long} = Events.rename_form_field(event, "camisa", too_long)
    end

    test "refuses an id that does not exist on the event" do
      event = seed()

      assert {:error, :not_found} = Events.rename_form_field(event, "ghost", "Alguma")
    end

    test "refuses to rename the locked name field" do
      event = seed()

      assert {:error, :locked_field} = Events.rename_form_field(event, "name", "Apelido")
    end
  end

  describe "the configuration screen" do
    test "lists the fields, with the name locked", %{conn: conn} do
      event = seed()

      {:ok, view, html} = live(as_admin(conn), ~p"/admin/r/#{event.slug}/formulario")

      assert html =~ "Nome"
      refute has_element?(view, ~s{button[aria-label="Remove field Nome"]})
    end

    test "adds a question from the form", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(as_admin(conn), ~p"/admin/r/#{event.slug}/formulario")
      html = render_submit(view, "add_field", %{"label" => "Camisa"})

      assert html =~ "Camisa"
      assert length(Events.form_fields(Events.find(event.slug))) == 2
    end

    test "removes one that is not locked", %{conn: conn} do
      event = seed()
      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa"})

      {:ok, view, _html} = live(as_admin(conn), ~p"/admin/r/#{event.slug}/formulario")
      render_click(view, "remove_field", %{"id" => "camisa"})

      assert length(Events.form_fields(Events.find(event.slug))) == 1
    end

    test "the pencil to rename is only rendered on non-locked fields", %{conn: conn} do
      event = seed()
      {:ok, _event} = Events.add_form_field(event, %{"label" => "Camisa"})

      {:ok, view, _html} = live(as_admin(conn), ~p"/admin/r/#{event.slug}/formulario")

      # The locked name row does NOT get a pencil.
      refute has_element?(
               view,
               ~s(button[phx-click="start_rename_field"][phx-value-id="name"])
             )

      # The organizer-added field does.
      assert has_element?(
               view,
               ~s(button[phx-click="start_rename_field"][phx-value-id="camisa"])
             )
    end

    test "clicking the pencil opens an inline rename form on that row", %{conn: conn} do
      event = seed()
      {:ok, _event} = Events.add_form_field(event, %{"label" => "Camisa"})

      {:ok, view, _html} = live(as_admin(conn), ~p"/admin/r/#{event.slug}/formulario")

      view
      |> element(~s(button[phx-click="start_rename_field"][phx-value-id="camisa"]))
      |> render_click()

      # The rename form is now on the page, scoped to this field id.
      assert has_element?(
               view,
               ~s(form[phx-submit="rename_field"][phx-value-id="camisa"])
             )
    end

    test "submitting the rename form updates the label and keeps the id stable",
         %{conn: conn} do
      event = seed()
      {:ok, _event} = Events.add_form_field(event, %{"label" => "Camisa"})

      {:ok, view, _html} = live(as_admin(conn), ~p"/admin/r/#{event.slug}/formulario")

      # Enter edit mode.
      view
      |> element(~s(button[phx-click="start_rename_field"][phx-value-id="camisa"]))
      |> render_click()

      # Submit the rename.
      view
      |> form(~s(form[phx-submit="rename_field"][phx-value-id="camisa"]), %{
        "label" => "Tamanho da camisa"
      })
      |> render_submit()

      reloaded = Events.find(event.slug)
      fields = Events.form_fields(reloaded)
      camisa = Enum.find(fields, &(&1.id == "camisa"))

      # The label moved, the id (and therefore any stored answer keyed by
      # it) did not.
      assert camisa.label == "Tamanho da camisa"
      assert camisa.id == "camisa"
    end

    test "the locked name field cannot be renamed even by a fabricated event",
         %{conn: conn} do
      # The pencil is hidden in the template, but a hostile client can still
      # push the message. The server has to say no.
      event = seed()
      {:ok, view, _html} = live(as_admin(conn), ~p"/admin/r/#{event.slug}/formulario")

      # start_rename_field is a no-op for a locked id — no edit form appears.
      render_hook(view, "start_rename_field", %{"id" => "name"})
      refute has_element?(view, ~s(form[phx-submit="rename_field"][phx-value-id="name"]))

      # And a rename attempt is rejected by the context.
      render_hook(view, "rename_field", %{"id" => "name", "label" => "Apelido"})

      reloaded = Events.find(event.slug)
      name_field = Enum.find(Events.form_fields(reloaded), &(&1.id == "name"))
      assert name_field.label == "Nome"
    end

    test "is admin-only", %{conn: conn} do
      event = seed()

      assert {:error, {:redirect, %{to: "/admin/login"}}} =
               live(conn, ~p"/admin/r/#{event.slug}/formulario")
    end
  end

  describe "answering (RN-62)" do
    test "the question shows up in the join sheet", %{conn: conn} do
      event = seed()
      {:ok, _} = Events.add_form_field(event, %{"label" => "Camisa"})

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      assert has_element?(view, ~s{input[name="camisa"]})
    end

    test "the answer lands on that person's row", %{conn: conn} do
      event = seed()
      {:ok, _} = Events.add_form_field(event, %{"label" => "Camisa"})

      post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Márcia", "camisa" => "M"})

      assert answers(event.slug, "Márcia") == %{"camisa" => "M"}
    end

    test "a required question blocks joining until it is answered", %{conn: conn} do
      event = seed()
      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa", "required" => "true"})
      _ = event

      post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Márcia"})

      assert Events.find(event.slug).main_list |> Enum.all?(&(&1.name == ""))
    end

    test "keys nobody asked about are not stored", %{conn: conn} do
      event = seed()

      post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Márcia", "cpf" => "12345678900"})

      assert answers(event.slug, "Márcia") == %{}
    end

    test "companions do not inherit the answers", %{conn: conn} do
      event = seed()
      {:ok, _} = Events.add_form_field(event, %{"label" => "Camisa"})

      post(conn, ~p"/r/#{event.slug}/join", %{
        "name" => "Márcia",
        "qty" => "2",
        "camisa" => "M"
      })

      # The guest never answered a shirt size; copying it would invent data.
      assert answers(event.slug, "Márcia") == %{"camisa" => "M"}
      assert answers(event.slug, "Convidado de Márcia") == %{}
    end

    test "answers render on the public list (single-field: inline next to the name)",
         %{conn: conn} do
      # Policy change (2026-09): answers used to be organizer-only, but the
      # product now shows them on `/r/:slug` so an attendee (and everyone
      # else who can see the list) can spot mistakes and, if allowed, fix
      # them in place. The unlock gate on password-protected events still
      # hides names + answers together, so nothing leaks around a password.
      event = seed()
      {:ok, _} = Events.add_form_field(event, %{"label" => "Camisa"})
      post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Márcia", "camisa" => "GG"})

      {:ok, _view, html} = live(build_conn(), ~p"/r/#{event.slug}")

      assert html =~ "Márcia"
      # Inline hint uses the pattern "<Label>: <value>" — the label is what
      # makes a bare "GG" readable.
      assert html =~ "Camisa: GG"
    end

    test "answers stay hidden on a password-gated event until the visitor unlocks",
         %{conn: conn} do
      # A locked event never leaks names in the public list; answers must
      # follow the same rule so the gate is worth anything.
      event = seed(%{"password" => "s3nh4"})
      {:ok, _} = Events.add_form_field(event, %{"label" => "Camisa"})

      # An admin conn to bypass the join gate, then a fresh unauthenticated
      # conn to read the page.
      admin_conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:admin?, true)

      post(admin_conn, ~p"/r/#{event.slug}/join", %{
        "name" => "Márcia",
        "camisa" => "GG-secreto"
      })

      {:ok, _view, html} = live(build_conn(), ~p"/r/#{event.slug}")

      refute html =~ "GG-secreto"
    end
  end
end

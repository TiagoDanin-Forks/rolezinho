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

    test "answers never reach the public list", %{conn: conn} do
      event = seed()
      {:ok, _} = Events.add_form_field(event, %{"label" => "Camisa"})
      post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Márcia", "camisa" => "GG-secreto"})

      {:ok, _view, html} = live(build_conn(), ~p"/r/#{event.slug}")

      assert html =~ "Márcia"
      refute html =~ "GG-secreto"
    end
  end
end

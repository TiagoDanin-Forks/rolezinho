defmodule RolezinhoWeb.AttendeeRowExtrasTest do
  @moduledoc """
  End-to-end coverage for the per-row extras on `/r/:slug`:

    * a single non-locked form field renders inline next to the name,
    * two or more fields hide behind a disclosure toggle (`Ver detalhes`
      / `Menos`) that flips the panel open,
    * admin, organizer, and the row's own owner see the edit pencil,
    * a stranger with no identity does not,
    * submitting `update_main` as an owner persists name + values;
      as a stranger, the row is untouched.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp create_event(overrides \\ %{}) do
    defaults = %{
      "title" => "Voléi",
      "slug" => "volei-#{System.unique_integer([:positive])}",
      "description" => "",
      "local" => "",
      "date" => "",
      "time" => "",
      "main_size" => "3",
      "wait_size" => "0",
      "password" => ""
    }

    {:ok, event} = Events.create(Map.merge(defaults, overrides), admin?: true)
    event
  end

  defp with_field(event, label) do
    {:ok, event} = Events.add_form_field(event, %{"label" => label})
    event
  end

  defp add_row(event, name, values, opts \\ []) do
    participant_id = Keyword.get(opts, :participant_id, "tok-#{name}")

    {:ok, event, _} =
      Events.add_party(event, name, 1,
        participant_id: participant_id,
        values: values
      )

    event
  end

  defp owner_conn(conn, participant_id, slug) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:participants, %{slug => participant_id})
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  describe "single-field event: inline hint" do
    test "renders `Label: value` next to the name for a filled row", %{conn: conn} do
      event = create_event() |> with_field("Camisa")
      _event = add_row(event, "Márcia", %{"camisa" => "G"})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "Márcia"
      assert html =~ "Camisa: G"
    end

    test "does NOT render an inline hint for a row with no answer", %{conn: conn} do
      # An empty answer should not leave a hanging separator (`" · "`) next
      # to the name — the inline hint is conditional on a real value.
      event = create_event() |> with_field("Camisa")
      _event = add_row(event, "Beto", %{})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "Beto"
      refute html =~ "Camisa:"
    end
  end

  describe "multi-field event: disclosure toggle" do
    test "hides the values by default; toggling reveals them", %{conn: conn} do
      event =
        create_event()
        |> with_field("Camisa")
        |> with_field("Data")

      event = add_row(event, "Ana", %{"camisa" => "M", "data" => "03/08"})

      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}")

      # Toggle button is present, values are not (yet).
      assert has_element?(
               view,
               ~s(button[phx-click="toggle_row_extras"][phx-value-list="main"][phx-value-index="1"])
             )

      assert html =~ "Ver detalhes"
      refute html =~ "03/08"

      # Click the disclosure — the panel opens.
      view
      |> element(
        ~s(button[phx-click="toggle_row_extras"][phx-value-list="main"][phx-value-index="1"])
      )
      |> render_click()

      html = render(view)
      assert html =~ "Menos"
      assert html =~ "03/08"
      assert html =~ "Camisa"
      assert html =~ "Data"
    end
  end

  describe "edit permissions on the row" do
    test "admin sees the pencil", %{conn: conn} do
      event = create_event() |> with_field("Camisa")
      _event = add_row(event, "Márcia", %{"camisa" => "M"})

      {:ok, view, _html} = live(admin_conn(conn), ~p"/r/#{event.slug}")

      assert has_element?(
               view,
               ~s(button[phx-click="start_edit_main"][phx-value-index="1"])
             )
    end

    test "the row's own owner sees the pencil", %{conn: conn} do
      event = create_event() |> with_field("Camisa")
      _event = add_row(event, "Márcia", %{"camisa" => "M"}, participant_id: "tok-marcia")

      conn = owner_conn(conn, "tok-marcia", event.slug)
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      assert has_element?(
               view,
               ~s(button[phx-click="start_edit_main"][phx-value-index="1"])
             )
    end

    test "a stranger with no identity does NOT see the pencil", %{conn: conn} do
      event = create_event() |> with_field("Camisa")
      _event = add_row(event, "Márcia", %{"camisa" => "M"}, participant_id: "tok-marcia")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      refute has_element?(
               view,
               ~s(button[phx-click="start_edit_main"][phx-value-index="1"])
             )
    end
  end

  describe "update path" do
    test "the row's owner can save a new name + value", %{conn: conn} do
      event = create_event() |> with_field("Camisa")
      _event = add_row(event, "Márcia", %{"camisa" => "M"}, participant_id: "tok-marcia")

      conn = owner_conn(conn, "tok-marcia", event.slug)
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      # Enter edit mode.
      view
      |> element(~s(button[phx-click="start_edit_main"][phx-value-index="1"]))
      |> render_click()

      # Submit the edit form.
      view
      |> form(~s(form[phx-submit="update_main"][phx-value-index="1"]), %{
        "name" => "Marcia Fer.",
        "values" => %{"camisa" => "GG"}
      })
      |> render_submit()

      reloaded = Events.find(event.slug)
      row = List.first(reloaded.main_list)
      assert row.name == "Marcia Fer."
      assert row.values == %{"camisa" => "GG"}
    end

    test "a stranger's update event is a silent no-op", %{conn: conn} do
      # The server is what enforces the gate — a fabricated `update_main`
      # from someone who does not own the row must not touch it.
      event = create_event() |> with_field("Camisa")
      _event = add_row(event, "Márcia", %{"camisa" => "M"}, participant_id: "tok-marcia")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      # No form is rendered for the stranger (no edit mode), so simulate
      # the hostile event directly.
      render_hook(view, "update_main", %{
        "index" => "1",
        "name" => "Hacker",
        "values" => %{"camisa" => "hax"}
      })

      reloaded = Events.find(event.slug)
      row = List.first(reloaded.main_list)
      assert row.name == "Márcia"
      assert row.values == %{"camisa" => "M"}
    end
  end
end

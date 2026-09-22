defmodule RolezinhoWeb.HiddenFlagUiTest do
  @moduledoc """
  UI surfaces for the `hidden` boolean, post the 2026-09 split:

    * `EventNewLive`: an "Oculto" checkbox that maps to a `hidden`
      param on the POST, wired through `Events.create/2` via
      `initial_hidden?/2`.
    * `EventLive` header: a visibility toggle button for anyone with
      `Policy.can_edit?/2` (admin OR organizer). Server-side handler
      re-checks the role.
    * `EventLive`: a stranger without edit rights sees no toggle and
      the fabricated event is silently ignored.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Events

  defp signed_in_conn(conn, login \\ "creator") do
    {:ok, user} =
      Accounts.find_or_create_by_github(%{
        "github_id" => System.unique_integer([:positive]),
        "github_login" => login
      })

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:current_user_id, user.id)

    {conn, user}
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  defp create_event(overrides, opts \\ [admin?: true]) do
    defaults = %{
      "title" => "Rolê",
      "slug" => "e-#{System.unique_integer([:positive])}",
      "main_size" => "3",
      "wait_size" => "0"
    }

    {:ok, event} = Events.create(Map.merge(defaults, overrides), opts)
    event
  end

  describe "EventNewLive Oculto checkbox" do
    test "renders an Oculto checkbox in the visibility section", %{conn: conn} do
      {conn, _} = signed_in_conn(conn)
      {:ok, view, html} = live(conn, ~p"/criar")

      assert has_element?(view, ~s(input[type="checkbox"][name="event[hidden]"]))
      assert html =~ "Visibilidade"
      assert html =~ "Oculto"
    end

    test "posting the form with hidden=true persists the event as hidden", %{conn: conn} do
      {conn, _} = signed_in_conn(conn, "hidden-creator")

      # POST straight to the endpoint since the LiveView form submits an
      # HTTP request (see EventCreateController).
      slug = "hidden-#{System.unique_integer([:positive])}"

      post(conn, ~p"/criar", %{
        "event" => %{
          "title" => "Escondido",
          "slug" => slug,
          "main_size" => "3",
          "wait_size" => "0",
          "hidden" => "true"
        }
      })

      event = Events.find(slug)
      assert event, "event should have been created"
      assert event.hidden == true
    end

    test "unchecked Oculto for a signed-in creator yields a visible event", %{conn: conn} do
      {conn, _} = signed_in_conn(conn, "visible-creator")

      slug = "vis-#{System.unique_integer([:positive])}"

      post(conn, ~p"/criar", %{
        "event" => %{
          "title" => "Publico",
          "slug" => slug,
          "main_size" => "3",
          "wait_size" => "0"
        }
      })

      event = Events.find(slug)
      assert event, "event should have been created"
      assert event.hidden == false
    end
  end

  describe "EventLive Oculto toggle" do
    test "admin sees the toggle and can flip the flag", %{conn: conn} do
      event = create_event(%{"slug" => "toggle-1"})
      conn = admin_conn(conn)

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      assert has_element?(view, ~s(button[phx-click="toggle_hidden"]))

      view
      |> element(~s(button[phx-click="toggle_hidden"]))
      |> render_click()

      assert Events.find("toggle-1").hidden == true
    end

    test "the event's organizer (via token) sees the toggle and can flip", %{conn: conn} do
      event = create_event(%{"slug" => "toggle-org-1"})

      # Simulate holding the organizer token: what the JoinController /
      # EventCreateController put in the session at creation time.
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:organizer_tokens, %{event.slug => event.organizer_token})

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      assert has_element?(view, ~s(button[phx-click="toggle_hidden"]))

      view
      |> element(~s(button[phx-click="toggle_hidden"]))
      |> render_click()

      assert Events.find("toggle-org-1").hidden == true
    end

    test "a stranger does NOT see the toggle", %{conn: conn} do
      event = create_event(%{"slug" => "toggle-stranger-1"})

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      refute has_element?(view, ~s(button[phx-click="toggle_hidden"]))
    end

    test "a stranger's fabricated toggle_hidden event is a silent no-op", %{conn: conn} do
      # The template hides the button; the server has to say no anyway,
      # because a hostile client can push the event without one.
      event = create_event(%{"slug" => "toggle-hostile-1"})

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")
      render_hook(view, "toggle_hidden", %{})

      # Flag is unchanged.
      assert Events.find("toggle-hostile-1").hidden == false
    end
  end
end

defmodule RolezinhoWeb.JoinSheetTest do
  @moduledoc """
  The join action and the sheet behind it.

  The sheet is rendered only when joining is actually allowed. A hidden sheet is
  still markup someone can submit, so its absence — not a CSS class — is what
  enforces the rule.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp create_event(attrs \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei-join-#{System.unique_integer([:positive])}",
      "description" => "End: Praia",
      "main_size" => "2",
      "wait_size" => "2"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  describe "the primary action" do
    test "offers the list while there is room", %{conn: conn} do
      event = create_event()

      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}")

      assert has_element?(view, "#join-form")
      assert html =~ "Entrar na lista"
    end

    test "offers the queue once the list is full (RN-03)", %{conn: conn} do
      event = create_event(%{"main_size" => "1"})
      {:ok, _} = Events.add_to_main(event, "Ana", participant_id: "someone")

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "Entrar na espera"
      refute html =~ "Entrar na lista"
      assert html =~ "sobe se alguém sair"
    end

    test "disappears for someone already on the list", %{conn: conn} do
      event = create_event()
      conn = post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Bruno"})

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      # Offering it again would let the same person take a second slot.
      refute has_element?(view, "#join-form")
    end

    test "disappears when the event is closed", %{conn: conn} do
      event = create_event()
      {:ok, _} = Events.set_status(event, :done)

      admin =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:admin?, true)

      {:ok, view, _html} = live(admin, ~p"/r/#{event.slug}")

      refute has_element?(view, "#join-form")
    end

    test "is absent from a locked event, not merely hidden", %{conn: conn} do
      event = create_event(%{"password" => "segredo"})

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      refute has_element?(view, "#join-form")
      refute has_element?(view, "#join-sheet")
    end

    test "a full list with no queue offers nothing", %{conn: conn} do
      event = create_event(%{"main_size" => "1", "wait_size" => "0"})
      {:ok, _} = Events.add_to_main(event, "Ana", participant_id: "someone")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      refute has_element?(view, "#join-form")
    end
  end

  describe "the sheet" do
    test "posts to the join endpoint rather than the socket", %{conn: conn} do
      event = create_event()

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      assert has_element?(view, ~s{form#join-form[action="/r/#{event.slug}/join"][method="post"]})
    end

    test "sends someone to the queue when the list is full", %{conn: conn} do
      event = create_event(%{"main_size" => "1"})
      {:ok, _} = Events.add_to_main(event, "Ana", participant_id: "someone")

      # The destination is resolved server-side from the room actually left, not
      # from a hidden field the client could have been holding since page load.
      post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Bruno"})

      reloaded = Events.find(event.slug)
      assert Enum.map(reloaded.wait_list, & &1.name) == ["Bruno"]
      assert Enum.map(reloaded.main_list, & &1.name) == ["Ana"]
    end

    test "carries the field the saved profile fills in", %{conn: conn} do
      event = create_event()

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      assert has_element?(view, ~s{input[name="name"][data-profile="name"]})
    end
  end
end

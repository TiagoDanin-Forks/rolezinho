defmodule RolezinhoWeb.EventLiveTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp seed_event(attrs \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei",
      "description" => "End: Praia\nHorário: 19h",
      "main_size" => "3",
      "wait_size" => "2"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  describe "public view" do
    setup do
      %{event: seed_event()}
    end

    test "renders title and header", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      assert html =~ "Vôlei"
      assert html =~ "Praia"
    end

    test "anyone can add themselves to the main list", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> form("#add-main-form", %{"name" => "Alice"})
      |> render_submit()

      assert render(view) =~ "Alice"
    end

    test "anyone can add themselves to the wait list", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> form("#add-wait-form", %{"name" => "Waiter"})
      |> render_submit()

      assert render(view) =~ "Waiter"
    end

    test "anyone can promote wait list to main", %{conn: conn, event: event} do
      # Fill main to leave 2 spots
      {:ok, _} = Events.add_to_main(event, "A")
      event = Events.find(event.slug)
      {:ok, _} = Events.add_to_wait(event, "W1")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> element("button[phx-click=\"promote\"][phx-value-index=\"1\"]")
      |> render_click()

      assert render(view) =~ "W1"
      # No more wait list entries
      refute render(view) =~ "1 pessoa"
    end

    test "does not show admin-only controls when not logged in", %{conn: conn, event: event} do
      {:ok, event} = Events.add_to_main(event, "A")

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      refute html =~ "phx-click=\"toggle_paid_main\""
      refute html =~ "phx-click=\"remove_main\""
      refute html =~ "phx-click=\"grow_main\""
      _ = event
    end
  end

  describe "admin view" do
    setup %{conn: conn} do
      event = seed_event()
      {:ok, event} = Events.add_to_main(event, "Márcia")

      %{conn: admin_conn(conn), event: event}
    end

    test "shows admin controls", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      assert html =~ "phx-click=\"toggle_paid_main\""
      assert html =~ "phx-click=\"grow_main\""
      assert html =~ "Editar"
    end

    test "admin can toggle paid", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> element("button[phx-click=\"toggle_paid_main\"][phx-value-index=\"1\"]")
      |> render_click()

      reloaded = Events.find(event.slug)
      assert Enum.at(reloaded.main_list, 0).paid == true
    end

    test "admin can grow the main list", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> element("button[phx-click=\"grow_main\"]")
      |> render_click()

      reloaded = Events.find(event.slug)
      assert reloaded.main_capacity == event.main_capacity + 1
    end

    test "admin can remove someone and everyone shifts up", %{conn: conn, event: event} do
      {:ok, event} = Events.add_to_main(event, "Bianca")
      {:ok, _event} = Events.add_to_main(event, "Carlos")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> element("button[phx-click=\"remove_main\"][phx-value-index=\"1\"]")
      |> render_click()

      reloaded = Events.find(event.slug)
      names = Enum.map(reloaded.main_list, & &1.name)
      assert names == ["Bianca", "Carlos", ""]
    end
  end

  test "returns to home when the slug does not exist", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/r/nao-existe")
  end
end

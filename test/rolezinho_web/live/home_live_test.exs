defmodule RolezinhoWeb.HomeLiveTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  # `admin?: true` because these tests are about what the home page lists, and
  # only an admin's events are born listed — everyone else's start hidden and
  # open by link (see `Events.create/2`).
  defp create_event(attrs) do
    defaults = %{"main_size" => "5", "wait_size" => "2"}
    {:ok, event} = Events.create(Map.merge(defaults, attrs), admin?: true)
    event
  end

  test "shows the empty state when there are no rolezinhos", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Rolezinhos"
    assert html =~ "Nenhum rolê por aqui"
  end

  test "lists active rolezinhos", %{conn: conn} do
    create_event(%{"title" => "Vôlei Beach", "slug" => "volei-beach"})

    {:ok, view, _html} = live(conn, ~p"/")

    assert render(view) =~ "Vôlei Beach"
    assert has_element?(view, ~s{a[href="/r/volei-beach"]})
  end

  test "does not list hidden rolezinhos", %{conn: conn} do
    event = create_event(%{"title" => "Secreto", "slug" => "secreto"})
    {:ok, _} = Events.set_status(event, :hidden)

    {:ok, view, _html} = live(conn, ~p"/")

    refute render(view) =~ "Secreto"
  end

  describe "category filter" do
    test "stays hidden while the list is short enough to scan", %{conn: conn} do
      create_event(%{"title" => "Vôlei", "slug" => "volei", "category" => "esporte"})

      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "[role=radiogroup]")
    end

    test "appears once there is enough to filter", %{conn: conn} do
      for i <- 1..4 do
        create_event(%{
          "title" => "Rolê #{i}",
          "slug" => "role-#{i}",
          "category" => if(rem(i, 2) == 0, do: "esporte", else: "social")
        })
      end

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "[role=radiogroup]")
      assert has_element?(view, "[role=radio]", "esporte")
    end

    test "narrows the listing to one category", %{conn: conn} do
      for i <- 1..4 do
        create_event(%{
          "title" => "Rolê #{i}",
          "slug" => "role-#{i}",
          "category" => if(rem(i, 2) == 0, do: "esporte", else: "social")
        })
      end

      {:ok, view, _html} = live(conn, ~p"/")
      html = view |> element("[role=radio]", "esporte") |> render_click()

      assert html =~ "Rolê 2"
      refute html =~ "Rolê 1"
    end

    test "explains an empty category instead of looking broken", %{conn: conn} do
      for i <- 1..4 do
        create_event(%{"title" => "Rolê #{i}", "slug" => "role-#{i}", "category" => "esporte"})
      end

      {:ok, view, _html} = live(conn, ~p"/")
      html = render_click(view, "filter", %{"id" => "social"})

      assert html =~ "Nada nessa categoria"
    end
  end
end

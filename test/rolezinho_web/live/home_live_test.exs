defmodule RolezinhoWeb.HomeLiveTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  test "shows the empty state when there are no rolezinhos", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Rolezinhos abertos"
    assert html =~ "Nenhum rolezinho ativo"
  end

  test "lists active rolezinhos", %{conn: conn} do
    {:ok, _} =
      Events.create(%{
        "title" => "Vôlei Beach",
        "slug" => "volei-beach",
        "main_size" => "5",
        "wait_size" => "2"
      })

    {:ok, view, _html} = live(conn, ~p"/")
    assert render(view) =~ "Vôlei Beach"
    assert render(view) =~ "/r/volei-beach"
  end

  test "does not list hidden rolezinhos", %{conn: conn} do
    {:ok, event} =
      Events.create(%{
        "title" => "Secreto",
        "slug" => "secreto",
        "main_size" => "5",
        "wait_size" => "0"
      })

    {:ok, _} = Events.set_status(event, :hidden)

    {:ok, view, _html} = live(conn, ~p"/")
    refute render(view) =~ "Secreto"
  end
end

defmodule RolezinhoWeb.AdminFlowTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  test "login flow", %{conn: conn} do
    conn = post(conn, ~p"/admin/login", %{"password" => "test-admin-password"})
    assert redirected_to(conn) == ~p"/admin"
    assert get_session(conn, :admin?) == true
  end

  test "login with wrong password fails", %{conn: conn} do
    conn = post(conn, ~p"/admin/login", %{"password" => "wrong"})
    assert html_response(conn, 401) =~ "Senha inválida"
    refute get_session(conn, :admin?)
  end

  test "non-admin cannot reach admin pages", %{conn: conn} do
    conn = get(conn, ~p"/admin")
    assert redirected_to(conn) == "/admin/login"
  end

  test "admin sees the dashboard", %{conn: conn} do
    {:ok, _view, html} =
      conn
      |> admin_conn()
      |> live(~p"/admin")

    assert html =~ "Painel do admin"
    assert html =~ "Criar rolezinho"
  end

  test "admin creates a rolezinho through the form", %{conn: conn} do
    {:ok, view, _html} =
      conn
      |> admin_conn()
      |> live(~p"/admin/new")

    {:error, {:live_redirect, %{to: to}}} =
      view
      |> form("#new-event-form", %{
        "event" => %{
          "title" => "Teste UI",
          "slug" => "teste-ui",
          "description" => "Detalhes",
          "main_size" => "5",
          "wait_size" => "2"
        }
      })
      |> render_submit()

    assert to == "/r/teste-ui"
    assert Events.find("teste-ui").title == "Teste UI"
  end
end

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

  test "anyone can create a rolezinho, and gets to administer it", %{conn: conn} do
    # RN-20: whoever creates is the organizer. Creating posts rather than
    # submitting over the socket, because the organizer secret has to land in the
    # session and a LiveView cannot write there.
    conn =
      post(conn, ~p"/criar", %{
        "event" => %{
          "title" => "Teste UI",
          "slug" => "teste-ui",
          "description" => "Detalhes",
          "main_size" => "5",
          "wait_size" => "2"
        }
      })

    assert redirected_to(conn) == "/r/teste-ui"

    event = Events.find("teste-ui")
    assert event.title == "Teste UI"

    # And the secret reached the browser, so they can actually manage it.
    assert %{"teste-ui" => token} = Plug.Conn.get_session(conn, "organizer_tokens")
    assert token == event.organizer_token
  end

  # A public home page that anyone can post to is a wall. Non-admin events open
  # by link, which is how they get shared anyway, and stay off the listing.
  test "an event created by a visitor is born hidden", %{conn: conn} do
    post(conn, ~p"/criar", %{
      "event" => %{"title" => "Do Zé", "slug" => "do-ze", "main_size" => "4"}
    })

    assert Events.find("do-ze").status == :hidden
    refute "do-ze" in Enum.map(Events.list_open(), & &1.slug)
  end

  test "an event created by the admin is active", %{conn: conn} do
    conn
    |> admin_conn()
    |> post(~p"/criar", %{
      "event" => %{"title" => "Do Admin", "slug" => "do-admin", "main_size" => "4"}
    })

    assert Events.find("do-admin").status == :active
    assert "do-admin" in Enum.map(Events.list_open(), & &1.slug)
  end

  test "a hidden event still opens by link for a visitor", %{conn: conn} do
    post(conn, ~p"/criar", %{
      "event" => %{"title" => "Do Zé", "slug" => "do-ze", "main_size" => "4"}
    })

    assert {:ok, _view, html} = live(conn, ~p"/r/do-ze")
    assert html =~ "Do Zé"
  end

  test "the create form is reachable without signing in", %{conn: conn} do
    assert {:ok, _view, html} = live(conn, ~p"/criar")
    assert html =~ "Criar rolezinho"
  end
end

defmodule RolezinhoWeb.AdminFlowTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Events

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  # A minimal signed-in-user session, per ADR-0002. Used to exercise the
  # "creator is a signed-in GitHub user" path without going through the OAuth
  # dance.
  defp signed_in_conn(conn, attrs \\ %{}) do
    defaults = %{
      "github_id" => System.unique_integer([:positive]),
      "github_login" => "gh-user",
      "name" => "Ghost User",
      "email" => nil,
      "avatar_url" => nil
    }

    {:ok, user} = Accounts.find_or_create_by_github(Map.merge(defaults, attrs))

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
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

  describe "creation requires a signed-in user or admin (ADR-0002)" do
    test "anonymous POST to /criar redirects to /entrar", %{conn: conn} do
      conn =
        post(conn, ~p"/criar", %{
          "event" => %{
            "title" => "Anônimo",
            "slug" => "anon-1",
            "main_size" => "5"
          }
        })

      # The event is not created.
      assert Events.find("anon-1") == nil
      # And the visitor is sent to sign in, with a return_to that comes back
      # to /criar.
      assert redirected_to(conn) =~ "/entrar"
      assert redirected_to(conn) =~ "return_to"
    end

    test "anonymous GET /criar (LiveView) redirects to /entrar too", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: to}}} = live(conn, ~p"/criar")
      assert String.starts_with?(to, "/entrar")
    end

    test "a signed-in user can create, and the event is born :active", %{conn: conn} do
      conn =
        conn
        |> signed_in_conn(%{"github_login" => "creator", "github_id" => 424_242})
        |> post(~p"/criar", %{
          "event" => %{
            "title" => "Do Signed-in",
            "slug" => "do-signed",
            "main_size" => "5"
          }
        })

      assert redirected_to(conn) == "/r/do-signed"
      event = Events.find("do-signed")
      assert event.status == :active
      assert "do-signed" in Enum.map(Events.list_open(), & &1.slug)

      # And the ownership pointer was set from the session, not from params.
      assert is_integer(event.created_by_user_id)
    end

    test "an admin can create without being signed in as a user", %{conn: conn} do
      conn =
        conn
        |> admin_conn()
        |> post(~p"/criar", %{
          "event" => %{
            "title" => "Do Admin",
            "slug" => "do-admin",
            "main_size" => "4"
          }
        })

      assert redirected_to(conn) == "/r/do-admin"
      event = Events.find("do-admin")
      assert event.status == :active
      # Admin creations without a signed-in session leave the ownership pointer
      # null (the admin bypass is orthogonal, per SECURITY.md).
      assert is_nil(event.created_by_user_id)
    end
  end

  test "signed-in creator becomes the organizer via the session token too", %{conn: conn} do
    # Belt-and-suspenders check: the create response still drops the
    # organizer_token in the session, in case the user later signs out and
    # keeps managing the event from that browser.
    conn =
      conn
      |> signed_in_conn(%{"github_login" => "belt-user", "github_id" => 99_001})
      |> post(~p"/criar", %{
        "event" => %{"title" => "Teste UI", "slug" => "teste-ui", "main_size" => "5"}
      })

    assert redirected_to(conn) == "/r/teste-ui"
    event = Events.find("teste-ui")
    assert %{"teste-ui" => token} = Plug.Conn.get_session(conn, "organizer_tokens")
    assert token == event.organizer_token
  end
end

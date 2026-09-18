defmodule RolezinhoWeb.AuthControllerTest do
  @moduledoc """
  Tests the OAuth callback flow at the controller level, injecting a fake
  `%Ueberauth.Auth{}` into `conn.assigns[:ueberauth_auth]` before dispatching
  to the callback action. This bypasses the real HTTP-to-GitHub round trip
  and lets us exercise the "what happens after GitHub says yes" branch —
  which is the interesting one.
  """
  use RolezinhoWeb.ConnCase, async: false

  alias Rolezinho.Accounts

  # Builds an `%Ueberauth.Auth{}` the way ueberauth_github hands it to us
  # on success.
  defp fake_auth(attrs \\ %{}) do
    defaults = %{
      uid: 424_242,
      login: "octocat",
      name: "Octo Cat",
      email: "octo@example.com",
      image: "https://example.com/octo.png"
    }

    merged = Map.merge(defaults, attrs)

    %Ueberauth.Auth{
      uid: merged.uid,
      info: %Ueberauth.Auth.Info{
        nickname: merged.login,
        name: merged.name,
        email: merged.email,
        image: merged.image
      }
    }
  end

  # Runs a conn straight through the callback action, injecting the auth so
  # ueberauth's own request-phase plug does not need to be exercised. We call
  # `fetch_flash/2` explicitly because a bare action invocation skips the
  # browser pipeline where flash normally gets fetched.
  defp call_callback(conn, auth, params \\ %{}) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Phoenix.Controller.fetch_flash([])
    |> Plug.Conn.assign(:ueberauth_auth, auth)
    |> RolezinhoWeb.AuthController.callback(Map.merge(%{"provider" => "github"}, params))
  end

  describe "successful callback" do
    test "creates the user and puts their id in the session", %{conn: conn} do
      conn = call_callback(conn, fake_auth())

      # Session survives.
      user_id = Plug.Conn.get_session(conn, :current_user_id)
      assert is_integer(user_id)
      assert user = Accounts.get_user(user_id)
      assert user.github_id == 424_242
      assert user.github_login == "octocat"

      # And the response is a redirect (home by default).
      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "octocat"
    end

    test "on a returning user, refreshes their fields without creating a duplicate",
         %{conn: conn} do
      # First sign-in.
      conn |> call_callback(fake_auth(%{login: "old-name"}))
      # Second sign-in: same uid, new login.
      conn = call_callback(conn, fake_auth(%{login: "new-name"}))

      user_id = Plug.Conn.get_session(conn, :current_user_id)
      assert user = Accounts.get_user(user_id)
      assert user.github_login == "new-name"

      # Only one user in the database.
      assert Rolezinho.Repo.aggregate(Accounts.User, :count) == 1
    end

    test "honors a safe `return_to`", %{conn: conn} do
      conn = call_callback(conn, fake_auth(), %{"return_to" => "/criar"})
      assert redirected_to(conn) == "/criar"
    end

    test "rejects an unsafe `return_to` (open redirect defense)", %{conn: conn} do
      conn = call_callback(conn, fake_auth(), %{"return_to" => "https://evil.example/phish"})
      assert redirected_to(conn) == "/"
    end

    test "rejects a protocol-relative `return_to`", %{conn: conn} do
      conn = call_callback(conn, fake_auth(), %{"return_to" => "//evil"})
      assert redirected_to(conn) == "/"
    end
  end

  describe "failed callback" do
    test "does not put anything in the session, redirects to /entrar", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Phoenix.Controller.fetch_flash([])
        |> Plug.Conn.assign(:ueberauth_failure, %Ueberauth.Failure{
          provider: :github,
          strategy: Ueberauth.Strategy.Github,
          errors: [%Ueberauth.Failure.Error{message_key: "denied", message: "denied"}]
        })
        |> RolezinhoWeb.AuthController.callback(%{"provider" => "github"})

      assert redirected_to(conn) == "/entrar"
      assert is_nil(Plug.Conn.get_session(conn, :current_user_id))
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "cancelado"
    end
  end

  describe "logout" do
    test "clears the session and redirects home", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{"current_user_id" => 999})
        |> Phoenix.Controller.fetch_flash([])
        |> RolezinhoWeb.AuthController.delete(%{})

      assert redirected_to(conn) == "/"
      assert is_nil(Plug.Conn.get_session(conn, :current_user_id))
    end
  end

  describe "sign-in prompt" do
    import Phoenix.LiveViewTest

    test "GET /entrar renders the GitHub button", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/entrar")
      assert html =~ "Entra com o GitHub"
      # The button points at the OAuth request endpoint with a return_to param.
      assert has_element?(view, "a[href*='/auth/github']")
    end

    test "signed-in visitors bounce off /entrar back home (or to return_to)", %{conn: conn} do
      {:ok, user} =
        Accounts.find_or_create_by_github(%{"github_id" => 1, "github_login" => "u"})

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:current_user_id, user.id)

      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/entrar")

      assert {:error, {:live_redirect, %{to: "/criar"}}} =
               live(conn, ~p"/entrar?return_to=%2Fcriar")
    end

    test "return_to values that aren't same-origin are ignored on the sign-in screen too",
         %{conn: conn} do
      {:ok, user} =
        Accounts.find_or_create_by_github(%{"github_id" => 2, "github_login" => "u"})

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:current_user_id, user.id)

      assert {:error, {:live_redirect, %{to: "/"}}} =
               live(conn, ~p"/entrar?return_to=https%3A%2F%2Fevil")
    end
  end
end

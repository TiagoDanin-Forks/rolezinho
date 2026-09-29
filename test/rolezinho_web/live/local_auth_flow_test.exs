defmodule RolezinhoWeb.LocalAuthFlowTest do
  @moduledoc """
  End-to-end for the local (username + password) auth path.

    * `/entrar` renders both the login and register forms.
    * `POST /entrar/registrar` creates a user, drops the id in the
      session, redirects.
    * `POST /entrar/senha` authenticates, drops the id in the session,
      redirects.
    * Wrong credentials bounce back to `/entrar` with an error flash.
    * `/me` shows the password panel and lets the signed-in user
      change / set the password.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Accounts.User

  describe "SignInLive at /entrar" do
    test "renders login form on default tab", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/entrar")

      assert has_element?(view, ~s(form#login-form[action="/entrar/senha"]))
      assert has_element?(view, ~s(input[name="username"]))
      assert has_element?(view, ~s(input[name="password"][type="password"]))
      # GitHub option is still there.
      assert html =~ "Continuar com GitHub"
    end

    test "renders register form on ?tab=registrar", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/entrar?tab=registrar")

      assert has_element?(view, ~s(form#register-form[action="/entrar/registrar"]))
      assert has_element?(view, ~s(input[name="email"]))
      assert has_element?(view, ~s(input[name="name"]))
    end

    # Regression: `type="email"` would trigger HTML5 format validation
    # on a non-empty malformed value and block submit, contradicting
    # the "email is optional and unverified" contract. Same reasoning
    # for `required` — the label already carries the "opcional" pill.
    test "email + name inputs are truly optional at the client layer", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/entrar?tab=registrar")

      # Email must be a plain text input (with an inputmode hint for
      # the mobile keyboard) and NOT `type="email"` / NOT `required`.
      assert has_element?(view, ~s(input[name="email"][type="text"]))
      assert has_element?(view, ~s(input[name="email"][inputmode="email"]))
      refute has_element?(view, ~s(input[name="email"][type="email"]))
      refute has_element?(view, ~s(input[name="email"][required]))

      # Name is optional too.
      assert has_element?(view, ~s(input[name="name"][type="text"]))
      refute has_element?(view, ~s(input[name="name"][required]))

      # Username + password remain required.
      assert has_element?(view, ~s(input[name="username"][required]))
      assert has_element?(view, ~s(input[name="password"][required]))
    end
  end

  describe "POST /entrar/registrar" do
    test "creates a user + session and redirects to /", %{conn: conn} do
      username = "regflow#{System.unique_integer([:positive])}"

      conn =
        post(conn, ~p"/entrar/registrar", %{
          "username" => username,
          "password" => "supersecret",
          "email" => "hi@example.com",
          "name" => "Regina"
        })

      assert redirected_to(conn) == "/"
      # The session carries the new user id.
      assert Plug.Conn.get_session(conn, :current_user_id)

      # And the user actually exists in the DB.
      assert %User{} = Accounts.get_by_username(username)
    end

    test "invalid input bounces back with a flash + preserved fields", %{conn: conn} do
      # Too-short password.
      conn =
        post(conn, ~p"/entrar/registrar", %{
          "username" => "shortpw#{System.unique_integer([:positive])}",
          "password" => "short",
          "email" => "hi@example.com"
        })

      redirect = redirected_to(conn)
      assert String.starts_with?(redirect, "/entrar?")
      assert redirect =~ "tab=registrar"
      # Username + email carried back in the query so the user doesn't
      # retype them; password never in the query, obviously.
      assert redirect =~ "username=shortpw"
      refute redirect =~ "password="
    end

    test "email is optional: registering without one succeeds", %{conn: conn} do
      username = "noemail#{System.unique_integer([:positive])}"

      # Three flavors of "no email" that a browser can produce.
      for email_value <- [nil, "", "   "] do
        this_username = "#{username}-#{System.unique_integer([:positive])}"

        params =
          %{"username" => this_username, "password" => "supersecret"}
          |> then(fn p ->
            if is_nil(email_value), do: p, else: Map.put(p, "email", email_value)
          end)

        conn = post(build_conn(), ~p"/entrar/registrar", params)

        assert redirected_to(conn) == "/",
               "expected email=#{inspect(email_value)} to register cleanly"

        # And the user landed in the DB with a nil email (not "").
        user = Accounts.get_by_username(this_username)
        assert user, "user should exist for email=#{inspect(email_value)}"
        assert is_nil(user.email), "expected nil email, got #{inspect(user.email)}"
      end
    end

    test "duplicate username bounces back with a flash", %{conn: conn} do
      username = "twice#{System.unique_integer([:positive])}"

      {:ok, _} = Accounts.register_user(%{"username" => username, "password" => "supersecret"})

      conn =
        post(conn, ~p"/entrar/registrar", %{
          "username" => username,
          "password" => "supersecret"
        })

      redirect = redirected_to(conn)
      assert String.starts_with?(redirect, "/entrar?")
      assert redirect =~ "tab=registrar"
    end
  end

  describe "POST /entrar/senha" do
    setup do
      username = "logflow#{System.unique_integer([:positive])}"

      {:ok, user} =
        Accounts.register_user(%{"username" => username, "password" => "correcthorse"})

      %{user: user, username: username}
    end

    test "right credentials produce a session and redirect", %{conn: conn, username: username} do
      conn =
        post(conn, ~p"/entrar/senha", %{"username" => username, "password" => "correcthorse"})

      assert redirected_to(conn) == "/"
      assert Plug.Conn.get_session(conn, :current_user_id)
    end

    test "return_to (safe local path) is honored", %{conn: conn, username: username} do
      conn =
        post(conn, ~p"/entrar/senha", %{
          "username" => username,
          "password" => "correcthorse",
          "return_to" => "/criar"
        })

      assert redirected_to(conn) == "/criar"
    end

    test "return_to (unsafe) collapses to /", %{conn: conn, username: username} do
      conn =
        post(conn, ~p"/entrar/senha", %{
          "username" => username,
          "password" => "correcthorse",
          "return_to" => "https://evil.example.com"
        })

      assert redirected_to(conn) == "/"
    end

    test "wrong password bounces back with a flash", %{conn: conn, username: username} do
      conn = post(conn, ~p"/entrar/senha", %{"username" => username, "password" => "wrong"})

      redirect = redirected_to(conn)
      assert String.starts_with?(redirect, "/entrar?")
      # No session.
      refute Plug.Conn.get_session(conn, :current_user_id)
    end
  end

  describe "/me password panel" do
    defp signed_in(conn, user) do
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:current_user_id, user.id)
    end

    test "local-auth user sees 'Alterar senha' and can change it", %{conn: conn} do
      username = "changer#{System.unique_integer([:positive])}"
      {:ok, user} = Accounts.register_user(%{"username" => username, "password" => "oldoldold"})

      {:ok, view, html} = live(signed_in(conn, user), ~p"/me")

      assert html =~ "Alterar senha"

      view
      |> form("form[phx-submit=\"set_password\"]", %{
        "current_password" => "oldoldold",
        "password" => "brandnewbrandnew"
      })
      |> render_submit()

      # And the DB actually took the new password.
      assert {:ok, %User{}} = Accounts.authenticate_user(username, "brandnewbrandnew")
    end

    test "GitHub-only user sees 'Definir senha' and can set one (no current password required)",
         %{conn: conn} do
      {:ok, user} =
        Accounts.find_or_create_by_github(%{
          "github_id" => System.unique_integer([:positive]),
          "github_login" => "ghset#{System.unique_integer([:positive])}"
        })

      refute user.password_hash

      {:ok, view, html} = live(signed_in(conn, user), ~p"/me")

      assert html =~ "Definir senha"
      # No current_password field for a first-time password.
      refute has_element?(view, ~s(input[name="current_password"]))

      view
      |> form("form[phx-submit=\"set_password\"]", %{"password" => "brandnewbrandnew"})
      |> render_submit()

      assert {:ok, %User{}} = Accounts.authenticate_user(user.username, "brandnewbrandnew")
    end
  end
end

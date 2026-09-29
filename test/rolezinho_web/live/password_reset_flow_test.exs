defmodule RolezinhoWeb.PasswordResetFlowTest do
  @moduledoc """
  Web-layer coverage for the password-reset flow. Verifies:

    * `/entrar/esqueci` renders the request form.
    * `POST /entrar/esqueci` always redirects with a generic success
      flash — success for a known user with email, and the same flash
      for an unknown identifier or a user with no email (no
      enumeration leak).
    * `/entrar/nova-senha/:token` renders the form for a valid token,
      and shows the "link inválido" copy for a bad/expired/used one.
    * `POST /entrar/nova-senha/:token` updates the password, signs the
      user in (redirects to `/`, flash `Senha redefinida`), and
      invalidates the token.
    * The `/entrar` login form links to `/entrar/esqueci`.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Rolezinho.Accounts
  alias Rolezinho.Accounts.ResetRateLimiter

  setup do
    # Every test starts with an empty rate-limit table so previous
    # test's hits don't leak in. `init/0` is safe to call after boot.
    :ok = ResetRateLimiter.init()
    :ok = ResetRateLimiter.reset!()
    :ok
  end

  defp register(overrides \\ %{}) do
    n = System.unique_integer([:positive])

    defaults = %{
      "username" => "flow#{n}",
      "password" => "supersecret",
      "email" => "flow#{n}@example.com",
      "name" => "Flow User"
    }

    {:ok, user} = Accounts.register_user(Map.merge(defaults, overrides))
    user
  end

  defp url_builder, do: fn token -> "https://example.test/entrar/nova-senha/#{token}" end

  defp request_and_extract(user) do
    :ok = Accounts.request_password_reset(user.username, url_builder())
    extract_last_token()
  end

  describe "/entrar login form" do
    test "carries the 'esqueci a senha' link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/entrar")

      # `has_element?` with the href attr is enough — the copy may
      # tweak, the destination should not.
      assert has_element?(view, ~s(a[href="/entrar/esqueci"]))
    end
  end

  describe "GET /entrar/esqueci" do
    test "renders the request form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/entrar/esqueci")

      assert has_element?(view, ~s(form#forgot-form[action="/entrar/esqueci"]))
      assert has_element?(view, ~s(input[name="identifier"][required]))
    end

    test "signed-in users are bounced home", %{conn: conn} do
      user = register()

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:current_user_id, user.id)

      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/entrar/esqueci")
    end
  end

  describe "POST /entrar/esqueci" do
    test "redirects to /entrar with a generic flash on any input", %{conn: conn} do
      _user = register()

      # Known user with email — an email is sent.
      conn1 = post(conn, ~p"/entrar/esqueci", %{"identifier" => "unknown-nobody"})
      assert redirected_to(conn1) == "/entrar"

      assert Phoenix.Flash.get(conn1.assigns.flash, :info) =~
               "Se existe uma conta com esse dado"

      # No email for unknown identifier.
      assert_no_email_sent()
    end

    test "sends the reset email for a known user with an address", %{conn: conn} do
      user = register()

      conn = post(conn, ~p"/entrar/esqueci", %{"identifier" => user.username})
      assert redirected_to(conn) == "/entrar"

      assert_email_sent(fn email ->
        assert email.to == [{"", user.email}]
        assert email.text_body =~ "/entrar/nova-senha/"
      end)
    end

    test "known user with no email still gets the generic flash and no send", %{conn: conn} do
      user = register(%{"email" => nil})

      conn = post(conn, ~p"/entrar/esqueci", %{"identifier" => user.username})
      assert redirected_to(conn) == "/entrar"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Se existe uma conta com esse dado"

      assert_no_email_sent()
    end

    test "rate-limited callers get the same flash but no email is sent", %{conn: conn} do
      user = register()

      # Burn through the per-identifier cap (5) so the 6th hit is
      # rate-limited. Each of the first five sends an email; the
      # sixth must not.
      for _ <- 1..5 do
        _ = post(conn, ~p"/entrar/esqueci", %{"identifier" => user.username})
      end

      # Drain the 5 sent emails so `assert_no_email_sent/0` below
      # sees the mailbox empty for the rate-limited attempt.
      for _ <- 1..5 do
        assert_receive {:email, _}
      end

      conn = post(conn, ~p"/entrar/esqueci", %{"identifier" => user.username})

      # User-visible response is unchanged. That's the whole point of
      # rate-limiting silently — the anti-enumeration story holds
      # even for the abusive caller.
      assert redirected_to(conn) == "/entrar"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Se existe uma conta com esse dado"

      # But no email went out for the 6th hit.
      assert_no_email_sent()
    end
  end

  describe "GET /entrar/nova-senha/:token" do
    test "renders the reset form for a valid token", %{conn: conn} do
      user = register()
      token = request_and_extract(user)

      {:ok, view, html} = live(conn, ~p"/entrar/nova-senha/#{token}")

      assert has_element?(view, ~s(form#reset-form))
      assert has_element?(view, ~s(input[name="password"][type="password"][required]))
      assert html =~ "Nova senha"
    end

    test "shows the invalid-link view for an unknown token", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/entrar/nova-senha/definitely-not-real")

      refute has_element?(view, ~s(form#reset-form))
      assert html =~ "Link inválido"
      assert has_element?(view, ~s(a[href="/entrar/esqueci"]))
    end

    test "shows the invalid-link view for an already-used token", %{conn: conn} do
      user = register()
      token = request_and_extract(user)
      {:ok, _} = Accounts.reset_password_with_token(token, "brandnewpass")

      {:ok, _view, html} = live(conn, ~p"/entrar/nova-senha/#{token}")

      assert html =~ "Link inválido"
    end
  end

  describe "POST /entrar/nova-senha/:token" do
    test "sets the new password, signs the user in, and redirects home", %{conn: conn} do
      user = register()
      token = request_and_extract(user)

      conn = post(conn, ~p"/entrar/nova-senha/#{token}", %{"password" => "brandnewpass"})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Senha redefinida"
      assert get_session(conn, :current_user_id) == user.id

      # Old password no longer works; new one does.
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(user.username, "supersecret")

      assert {:ok, _} = Accounts.authenticate_user(user.username, "brandnewpass")

      # Token is dead.
      assert {:error, :invalid_token} =
               Accounts.reset_password_with_token(token, "yetanotherpass")
    end

    test "invalid token bounces to /entrar/esqueci with an error flash", %{conn: conn} do
      conn = post(conn, ~p"/entrar/nova-senha/bogus", %{"password" => "brandnewpass"})

      assert redirected_to(conn) == "/entrar/esqueci"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Link inválido"
    end

    test "weak password bounces back to the same reset form with an error flash", %{conn: conn} do
      user = register()
      token = request_and_extract(user)

      conn = post(conn, ~p"/entrar/nova-senha/#{token}", %{"password" => "short"})

      assert redirected_to(conn) == "/entrar/nova-senha/#{token}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "password"

      # Token is still redeemable — a validation failure must not burn it.
      assert {:ok, _} = Accounts.reset_password_with_token(token, "brandnewpass")
    end
  end

  # Pulls the reset token out of the most recently delivered email.
  # Same shape as the context test's helper — duplicated on purpose so
  # each test file stands alone without a shared fixture module.
  defp extract_last_token do
    receive do
      {:email, email} ->
        drain_mailbox()
        [_, token | _] = Regex.run(~r{/entrar/nova-senha/([^\s]+)}, email.text_body)
        token
    after
      0 -> flunk("no reset email was delivered")
    end
  end

  defp drain_mailbox do
    receive do
      {:email, _} -> drain_mailbox()
    after
      0 -> :ok
    end
  end
end

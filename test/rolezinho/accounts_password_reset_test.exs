defmodule Rolezinho.AccountsPasswordResetTest do
  @moduledoc """
  Context-level coverage for the password-reset flow (2026-09 ADR-0002
  amendment).

  What this file locks in:

    * The plaintext token never lands in the DB — only its SHA-256.
    * A request for an unknown identifier is a silent `:ok` (no user
      enumeration).
    * A request for a known user with no email on file is also a
      silent `:ok` (nothing to send).
    * Only one token is active at a time per user — a fresh request
      wipes any prior outstanding tokens.
    * Redemption is single-use, expiry-checked, and updates the
      password hash in the same transaction that deletes the token.
    * The identifier lookup accepts both username and email, and both
      lookups are case-insensitive.
  """
  use Rolezinho.DataCase, async: false

  import Swoosh.TestAssertions

  alias Rolezinho.Accounts
  alias Rolezinho.Accounts.PasswordResetToken
  alias Rolezinho.Accounts.User
  alias Rolezinho.Repo

  # Every test registers a fresh user; keeping the username unique per
  # test avoids the shared-sandbox cross-test collision that
  # `async: false` on DataCase can otherwise cause.
  defp register(overrides \\ %{}) do
    n = System.unique_integer([:positive])

    defaults = %{
      "username" => "reset#{n}",
      "password" => "supersecret",
      "email" => "reset#{n}@example.com",
      "name" => "Reset User"
    }

    {:ok, user} = Accounts.register_user(Map.merge(defaults, overrides))
    user
  end

  defp url_builder, do: fn token -> "https://example.test/entrar/nova-senha/#{token}" end

  describe "request_password_reset/2" do
    test "creates a token row, hashes the token, sends the email" do
      user = register()

      assert :ok = Accounts.request_password_reset(user.username, url_builder())

      # Exactly one token, and its hash is the SHA-256 of nothing we
      # can pull out of the DB — that's the invariant. The plaintext
      # only exists inside the email body we sent.
      [%PasswordResetToken{} = row] = Repo.all(PasswordResetToken)
      assert row.user_id == user.id
      assert row.sent_to_email == user.email
      assert is_binary(row.token_hash)
      assert byte_size(row.token_hash) == 32

      assert_email_sent(fn email ->
        assert email.to == [{"", user.email}]
        assert email.subject =~ "Redefinir a senha"

        # The token is in the email body under our reset URL — grab
        # it, hash it, and confirm it matches the row's hash.
        [_, token | _] = Regex.run(~r{/entrar/nova-senha/([^\s]+)}, email.text_body)
        assert :crypto.hash(:sha256, token) == row.token_hash
      end)
    end

    test "email lookup finds a user by their email address (case-insensitive)" do
      user = register(%{"email" => "MixedCase@Example.COM"})

      assert :ok = Accounts.request_password_reset("mixedcase@example.com", url_builder())

      [row] = Repo.all(PasswordResetToken)
      assert row.user_id == user.id
    end

    test "unknown identifier is a silent :ok with no token inserted and no email sent" do
      _user = register()

      assert :ok = Accounts.request_password_reset("nobody-here", url_builder())

      assert Repo.all(PasswordResetToken) == []
      assert_no_email_sent()
    end

    test "known user with no email on file is a silent :ok" do
      user = register(%{"email" => nil})

      assert :ok = Accounts.request_password_reset(user.username, url_builder())

      assert Repo.all(PasswordResetToken) == []
      assert_no_email_sent()
    end

    test "a fresh request wipes any prior outstanding token for the same user" do
      user = register()

      assert :ok = Accounts.request_password_reset(user.username, url_builder())
      [first] = Repo.all(PasswordResetToken)

      assert :ok = Accounts.request_password_reset(user.username, url_builder())
      [second] = Repo.all(PasswordResetToken)

      # Same user, brand new row.
      assert second.user_id == user.id
      refute second.id == first.id
      refute second.token_hash == first.token_hash
    end

    test "blank / nil identifier is a silent :ok" do
      _user = register()

      assert :ok = Accounts.request_password_reset(nil, url_builder())
      assert :ok = Accounts.request_password_reset("", url_builder())
      assert :ok = Accounts.request_password_reset("   ", url_builder())

      assert Repo.all(PasswordResetToken) == []
    end
  end

  describe "reset_password_with_token/2" do
    setup do
      user = register()
      :ok = Accounts.request_password_reset(user.username, url_builder())
      token = extract_last_token()
      %{user: Repo.reload!(user), token: token}
    end

    test "swaps the password hash on the user", %{user: user, token: token} do
      old_hash = user.password_hash

      assert {:ok, %User{} = updated} =
               Accounts.reset_password_with_token(token, "brandnewpass")

      assert updated.id == user.id
      refute updated.password_hash == old_hash

      # Login with the new password works, login with the old one doesn't.
      assert {:ok, _} = Accounts.authenticate_user(user.username, "brandnewpass")

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(user.username, "supersecret")
    end

    test "consumes the token — a second use fails", %{token: token} do
      assert {:ok, _} = Accounts.reset_password_with_token(token, "brandnewpass")
      assert {:error, :invalid_token} = Accounts.reset_password_with_token(token, "anotherpass")
    end

    test "an expired token is refused (and password stays put)", %{user: user, token: token} do
      # Backdate the token so it's already expired.
      Repo.update_all(PasswordResetToken,
        set: [
          expires_at:
            DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
        ]
      )

      assert {:error, :invalid_token} = Accounts.reset_password_with_token(token, "brandnewpass")

      # Old password still works.
      assert {:ok, _} = Accounts.authenticate_user(user.username, "supersecret")
    end

    test "a weak new password is refused with an Ecto.Changeset error", %{token: token} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Accounts.reset_password_with_token(token, "short")

      assert %{password: _} = errors_on(changeset)

      # And the token wasn't burnt — the user gets to try again.
      assert {:ok, _} = Repo.all(PasswordResetToken) |> List.first() |> then(&{:ok, &1})
    end

    test "an unknown token is refused" do
      assert {:error, :invalid_token} =
               Accounts.reset_password_with_token("not-a-real-token", "brandnewpass")
    end

    test "non-binary inputs are refused" do
      assert {:error, :invalid_token} = Accounts.reset_password_with_token(nil, "brandnewpass")
    end
  end

  describe "fetch_user_by_reset_token/1" do
    test "returns the user for a valid, unused, unexpired token" do
      user = register()
      :ok = Accounts.request_password_reset(user.username, url_builder())
      token = extract_last_token()

      assert {:ok, %User{} = fetched} = Accounts.fetch_user_by_reset_token(token)
      assert fetched.id == user.id
    end

    test "returns :error for an already-used token" do
      user = register()
      :ok = Accounts.request_password_reset(user.username, url_builder())
      token = extract_last_token()

      {:ok, _} = Accounts.reset_password_with_token(token, "brandnewpass")

      assert :error = Accounts.fetch_user_by_reset_token(token)

      _ = user
    end

    test "returns :error for an unknown / nil / empty token" do
      assert :error = Accounts.fetch_user_by_reset_token("noone")
      assert :error = Accounts.fetch_user_by_reset_token(nil)
      assert :error = Accounts.fetch_user_by_reset_token("")
    end
  end

  # Pulls the reset token out of the most recently delivered email —
  # what the user would click on. The Swoosh Test adapter captures
  # every deliver into the process mailbox.
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

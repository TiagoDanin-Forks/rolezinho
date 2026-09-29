defmodule Rolezinho.AccountsLocalAuthTest do
  @moduledoc """
  Local (username + password) auth path added in the 2026-09 amendment
  to ADR-0002:

    * `register_user/1` — creates a user with a bcrypt-hashed password,
      validates username shape and password minimum length, and rejects
      duplicate usernames.
    * `authenticate_user/2` — verifies the pair in constant time;
      missing users still burn a bcrypt cycle so the timing signal
      doesn't leak existence.
    * `update_password/3` — a signed-in user's password change; first
      time (GitHub-only accounts opting in) skips the current-password
      check.
    * `find_or_create_by_github/1` — still works, and now auto-derives
      a `:username` on insert.
  """
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Accounts
  alias Rolezinho.Accounts.User

  # ---------- register_user/1 ----------

  describe "register_user/1" do
    test "creates a user with a hashed password" do
      assert {:ok, %User{} = user} =
               Accounts.register_user(%{
                 "username" => "alice1",
                 "password" => "supersecret"
               })

      assert user.username == "alice1"
      assert is_binary(user.password_hash)
      # Password itself is virtual + redact; never persisted.
      assert user.password == nil
      # Bcrypt hashes never start with the plaintext.
      refute String.contains?(user.password_hash, "supersecret")
    end

    test "downcases the username on the way in" do
      assert {:ok, %User{username: "alice2"}} =
               Accounts.register_user(%{"username" => "ALICE2", "password" => "supersecret"})
    end

    test "trims whitespace" do
      assert {:ok, %User{username: "alice3"}} =
               Accounts.register_user(%{"username" => "  alice3  ", "password" => "supersecret"})
    end

    test "rejects a username under 6 chars" do
      assert {:error, changeset} =
               Accounts.register_user(%{"username" => "ali", "password" => "supersecret"})

      assert Keyword.has_key?(changeset.errors, :username)
    end

    test "rejects a username starting with a digit" do
      assert {:error, changeset} =
               Accounts.register_user(%{"username" => "1alice", "password" => "supersecret"})

      assert Keyword.has_key?(changeset.errors, :username)
    end

    test "rejects a username with a disallowed character" do
      assert {:error, changeset} =
               Accounts.register_user(%{"username" => "ali ce", "password" => "supersecret"})

      assert Keyword.has_key?(changeset.errors, :username)
    end

    test "rejects a password under 8 chars" do
      assert {:error, changeset} =
               Accounts.register_user(%{"username" => "alice4", "password" => "short"})

      assert Keyword.has_key?(changeset.errors, :password)
    end

    test "rejects a duplicate username (case-insensitive)" do
      {:ok, _} = Accounts.register_user(%{"username" => "duplicate", "password" => "supersecret"})

      assert {:error, changeset} =
               Accounts.register_user(%{"username" => "DUPLICATE", "password" => "supersecret"})

      assert Keyword.has_key?(changeset.errors, :username)
    end

    test "email is optional; when present, stored as-is" do
      assert {:ok, %User{email: "alice@example.com"}} =
               Accounts.register_user(%{
                 "username" => "alice5",
                 "password" => "supersecret",
                 "email" => "alice@example.com"
               })

      assert {:ok, %User{email: nil}} =
               Accounts.register_user(%{"username" => "alice6", "password" => "supersecret"})
    end

    test "admin flag is mass-assignment-protected on register" do
      assert {:ok, %User{admin: false}} =
               Accounts.register_user(%{
                 "username" => "alice7",
                 "password" => "supersecret",
                 "admin" => true
               })
    end
  end

  # ---------- authenticate_user/2 ----------

  describe "authenticate_user/2" do
    # DataCase uses a shared sandbox in `async: false`, so registrations
    # persist across tests within the file. Each setup gets a unique
    # username to avoid the duplicate collision.
    setup do
      username = "carol#{System.unique_integer([:positive])}"

      {:ok, user} =
        Accounts.register_user(%{"username" => username, "password" => "correcthorse"})

      %{user: user, username: username}
    end

    test "returns {:ok, user} on the right pair", %{user: user, username: username} do
      assert {:ok, %User{id: id}} = Accounts.authenticate_user(username, "correcthorse")
      assert id == user.id
    end

    test "username lookup is case-insensitive", %{user: user, username: username} do
      assert {:ok, %User{id: id}} =
               Accounts.authenticate_user(String.upcase(username), "correcthorse")

      assert id == user.id
    end

    test "wrong password → :invalid_credentials", %{username: username} do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(username, "wrong-password")
    end

    test "unknown username → :invalid_credentials (constant-time)" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(
                 "nobody-#{System.unique_integer([:positive])}",
                 "anything"
               )
    end

    test "GitHub-only user (no password_hash) → :invalid_credentials" do
      {:ok, gh_user} =
        Accounts.find_or_create_by_github(%{
          "github_id" => System.unique_integer([:positive]),
          "github_login" => "ghonly#{System.unique_integer([:positive])}"
        })

      refute gh_user.password_hash

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user(gh_user.username, "anything")
    end

    test "non-binary inputs → :invalid_credentials, no crash", %{username: username} do
      assert {:error, :invalid_credentials} = Accounts.authenticate_user(nil, "x")
      assert {:error, :invalid_credentials} = Accounts.authenticate_user(username, nil)
      assert {:error, :invalid_credentials} = Accounts.authenticate_user(123, "x")
    end
  end

  # ---------- update_password/3 ----------

  describe "update_password/3" do
    test "a GitHub-only user (no password_hash) sets a first password without a current one" do
      {:ok, user} =
        Accounts.find_or_create_by_github(%{
          "github_id" => System.unique_integer([:positive]),
          "github_login" => "githubby#{System.unique_integer([:positive])}"
        })

      refute user.password_hash

      assert {:ok, updated} = Accounts.update_password(user, nil, "brand-new-password")
      assert is_binary(updated.password_hash)

      # And the pair now authenticates.
      assert {:ok, %User{}} = Accounts.authenticate_user(updated.username, "brand-new-password")
    end

    test "existing password: requires the current one" do
      username = "dora#{System.unique_integer([:positive])}"
      {:ok, user} = Accounts.register_user(%{"username" => username, "password" => "originalpw"})

      assert {:error, :invalid_current_password} =
               Accounts.update_password(user, "wrong", "newpassword")

      # The password did NOT change.
      assert {:ok, %User{}} = Accounts.authenticate_user(username, "originalpw")
    end

    test "existing password: right current password → new password takes over" do
      username = "erik#{System.unique_integer([:positive])}"
      {:ok, user} = Accounts.register_user(%{"username" => username, "password" => "originalpw"})

      assert {:ok, _updated} = Accounts.update_password(user, "originalpw", "newshinypw")
      assert {:error, :invalid_credentials} = Accounts.authenticate_user(username, "originalpw")
      assert {:ok, %User{}} = Accounts.authenticate_user(username, "newshinypw")
    end

    test "a too-short new password is rejected as a changeset error" do
      username = "flynn#{System.unique_integer([:positive])}"
      {:ok, user} = Accounts.register_user(%{"username" => username, "password" => "originalpw"})

      assert {:error, %Ecto.Changeset{} = changeset} =
               Accounts.update_password(user, "originalpw", "short")

      assert Keyword.has_key?(changeset.errors, :password)
    end
  end

  # ---------- find_or_create_by_github/1 auto-derives username ----------

  describe "find_or_create_by_github/1 (post-amendment)" do
    test "auto-derives username from github_login on insert" do
      {:ok, user} =
        Accounts.find_or_create_by_github(%{
          "github_id" => System.unique_integer([:positive]),
          "github_login" => "octopus"
        })

      assert user.username == "octopus"
    end

    test "downcases the derived username" do
      {:ok, user} =
        Accounts.find_or_create_by_github(%{
          "github_id" => System.unique_integer([:positive]),
          "github_login" => "OctoCat"
        })

      assert user.username == "octocat"
    end

    test "pads a short github_login to reach the 6-char minimum" do
      {:ok, user} =
        Accounts.find_or_create_by_github(%{
          "github_id" => System.unique_integer([:positive]),
          "github_login" => "me"
        })

      # "me" is 2 chars; pads with "0" to reach 6.
      assert user.username == "me0000"
    end

    test "prefixes a digit-first github_login so it starts with a letter" do
      {:ok, user} =
        Accounts.find_or_create_by_github(%{
          "github_id" => System.unique_integer([:positive]),
          "github_login" => "42answers"
        })

      assert String.starts_with?(user.username, "u-42answers")
    end

    test "suffixes on collision with an existing local-auth username" do
      {:ok, _} = Accounts.register_user(%{"username" => "shared", "password" => "supersecret"})

      {:ok, gh} =
        Accounts.find_or_create_by_github(%{
          "github_id" => System.unique_integer([:positive]),
          "github_login" => "shared"
        })

      # Base "shared" is taken; the deriver walks 1, 2, ... until free.
      assert gh.username == "shared1"
    end

    test "refreshing an existing GitHub user does NOT change their username" do
      github_id = System.unique_integer([:positive])

      {:ok, first} =
        Accounts.find_or_create_by_github(%{
          "github_id" => github_id,
          "github_login" => "renamed"
        })

      original_username = first.username

      # GitHub renames itself; we refresh github_login but keep username.
      {:ok, refreshed} =
        Accounts.find_or_create_by_github(%{
          "github_id" => github_id,
          "github_login" => "renamed-new"
        })

      assert refreshed.username == original_username
      assert refreshed.github_login == "renamed-new"
    end
  end
end

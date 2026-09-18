defmodule Rolezinho.AccountsTest do
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Accounts
  alias Rolezinho.Accounts.User

  describe "find_or_create_by_github/1" do
    test "creates a new user on the first call with a given github_id" do
      attrs = %{
        "github_id" => 12_345,
        "github_login" => "octocat",
        "name" => "Octo Cat",
        "email" => "octo@example.com",
        "avatar_url" => "https://example.com/octo.png"
      }

      assert {:ok, %User{} = user} = Accounts.find_or_create_by_github(attrs)
      assert user.github_id == 12_345
      assert user.github_login == "octocat"
      assert user.name == "Octo Cat"
      assert user.email == "octo@example.com"
      assert user.avatar_url == "https://example.com/octo.png"
    end

    test "does not duplicate — a second call for the same github_id refreshes the row" do
      {:ok, first} =
        Accounts.find_or_create_by_github(%{
          "github_id" => 42,
          "github_login" => "old-login",
          "name" => "Old Name"
        })

      {:ok, second} =
        Accounts.find_or_create_by_github(%{
          "github_id" => 42,
          "github_login" => "new-login",
          "name" => "New Name"
        })

      # Same DB row.
      assert second.id == first.id
      # But with the refreshed identity fields.
      assert second.github_login == "new-login"
      assert second.name == "New Name"
    end

    test "accepts github_id as a string too (some OAuth adapters hand it that way)" do
      assert {:ok, %User{github_id: 999}} =
               Accounts.find_or_create_by_github(%{
                 "github_id" => "999",
                 "github_login" => "user"
               })
    end

    test "rejects a missing github_id" do
      assert {:error, changeset} =
               Accounts.find_or_create_by_github(%{"github_login" => "user"})

      # Two errors surface: our explicit add_error and the underlying
      # validate_required. Either counts as "user was told what's missing".
      assert %{github_id: _} = errors_on(changeset)
    end

    test "rejects a garbage github_id" do
      assert {:error, changeset} =
               Accounts.find_or_create_by_github(%{
                 "github_id" => "not-a-number",
                 "github_login" => "user"
               })

      assert %{github_id: _} = errors_on(changeset)
    end

    test "length-caps the display strings" do
      long = String.duplicate("a", 500)

      assert {:error, changeset} =
               Accounts.find_or_create_by_github(%{
                 "github_id" => 7,
                 "github_login" => long
               })

      assert %{github_login: _} = errors_on(changeset)
    end
  end

  describe "get_user/1" do
    test "returns nil for a nil id, without hitting the database" do
      assert Accounts.get_user(nil) == nil
    end

    test "returns nil for an unknown id" do
      assert Accounts.get_user(-1) == nil
    end

    test "returns the user for a known id" do
      {:ok, user} =
        Accounts.find_or_create_by_github(%{
          "github_id" => 1,
          "github_login" => "user"
        })

      assert %User{id: same} = Accounts.get_user(user.id)
      assert same == user.id
    end
  end

  describe "User.display_name/1" do
    test "prefers the GitHub display name" do
      assert User.display_name(%User{name: "Full Name", github_login: "login"}) == "Full Name"
    end

    test "falls back to the login when the name is missing or blank" do
      assert User.display_name(%User{name: nil, github_login: "login"}) == "login"
      assert User.display_name(%User{name: "", github_login: "login"}) == "login"
    end

    test "never returns nil, even when both are missing" do
      assert User.display_name(%User{name: nil, github_login: nil}) == ""
    end
  end
end

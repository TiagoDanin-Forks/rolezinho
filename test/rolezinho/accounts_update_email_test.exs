defmodule Rolezinho.AccountsUpdateEmailTest do
  @moduledoc """
  Context coverage for `Accounts.update_email/2`. Locks in:

    * A plain string sets the email.
    * An empty / whitespace-only value clears the email (nil on the
      row) — matching the "email is optional" contract.
    * A value over the 200-char length cap is refused with an
      `Ecto.Changeset` error and the persisted row is untouched.
    * Mass-assignment protection stays intact: sending `email` does
      not let the caller flip `admin`, `password_hash`, `username`,
      or anything GitHub-side.
  """
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Accounts

  defp register(overrides \\ %{}) do
    n = System.unique_integer([:positive])

    defaults = %{
      "username" => "mailer#{n}",
      "password" => "supersecret",
      "email" => "mailer#{n}@example.com",
      "name" => "Mail User"
    }

    {:ok, user} = Accounts.register_user(Map.merge(defaults, overrides))
    user
  end

  test "sets a fresh email value" do
    user = register(%{"email" => nil})

    assert {:ok, updated} = Accounts.update_email(user, "new@example.com")
    assert updated.email == "new@example.com"
  end

  test "an empty string clears the email" do
    user = register()
    assert user.email != nil

    assert {:ok, cleared} = Accounts.update_email(user, "")
    assert cleared.email == nil
  end

  test "a whitespace-only value also clears the email" do
    user = register()

    assert {:ok, cleared} = Accounts.update_email(user, "   ")
    assert cleared.email == nil
  end

  test "trims surrounding whitespace before storing" do
    user = register(%{"email" => nil})

    assert {:ok, updated} = Accounts.update_email(user, "  spaced@example.com  ")
    assert updated.email == "spaced@example.com"
  end

  test "a nil value clears the email" do
    user = register()
    assert {:ok, cleared} = Accounts.update_email(user, nil)
    assert cleared.email == nil
  end

  test "an over-length email is refused, and the row on disk is unchanged" do
    user = register()
    huge = String.duplicate("a", 250) <> "@example.com"

    assert {:error, %Ecto.Changeset{} = changeset} = Accounts.update_email(user, huge)
    assert %{email: _} = errors_on(changeset)

    reloaded = Rolezinho.Repo.reload!(user)
    assert reloaded.email == user.email
  end

  test "the row's non-email fields are untouched by an update" do
    user = register()

    assert {:ok, updated} = Accounts.update_email(user, "different@example.com")
    assert updated.username == user.username
    assert updated.password_hash == user.password_hash
    assert updated.name == user.name
    assert updated.admin == user.admin
  end
end

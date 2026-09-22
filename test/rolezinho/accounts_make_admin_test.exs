defmodule Rolezinho.AccountsMakeAdminTest do
  @moduledoc """
  `Accounts.make_admin_by_handle/1` \u2014 the console-friendly entry point that
  flips a user's `:admin` flag by GitHub login. Lookup is case-insensitive
  and tolerates a leading `@`.
  """
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Accounts

  defp create_user(login, overrides \\ %{}) do
    defaults = %{
      "github_id" => System.unique_integer([:positive]),
      "github_login" => login,
      "name" => nil,
      "email" => nil,
      "avatar_url" => nil
    }

    {:ok, user} = Accounts.find_or_create_by_github(Map.merge(defaults, overrides))
    user
  end

  test "promotes an existing user to admin by login" do
    user = create_user("lubien")
    refute user.admin

    assert {:ok, promoted} = Accounts.make_admin_by_handle("lubien")
    assert promoted.id == user.id
    assert promoted.admin == true

    # Persisted, not just returned.
    assert Accounts.get_user(user.id).admin == true
  end

  test "lookup is case-insensitive" do
    user = create_user("Lubien")

    assert {:ok, promoted} = Accounts.make_admin_by_handle("lubien")
    assert promoted.id == user.id
    assert promoted.admin == true
  end

  test "tolerates a leading @ in the handle" do
    user = create_user("lubien")

    assert {:ok, promoted} = Accounts.make_admin_by_handle("@lubien")
    assert promoted.id == user.id
    assert promoted.admin == true
  end

  test "idempotent on an already-admin user" do
    user = create_user("lubien")
    {:ok, _} = Accounts.make_admin_by_handle("lubien")

    assert {:ok, still_admin} = Accounts.make_admin_by_handle("lubien")
    assert still_admin.id == user.id
    assert still_admin.admin == true
  end

  test "returns :not_found for an unknown handle" do
    assert {:error, :not_found} = Accounts.make_admin_by_handle("ghost")
  end

  test "empty and whitespace-only handles resolve to :not_found" do
    assert {:error, :not_found} = Accounts.make_admin_by_handle("")
    assert {:error, :not_found} = Accounts.make_admin_by_handle("   ")
    assert {:error, :not_found} = Accounts.make_admin_by_handle("@")
  end
end

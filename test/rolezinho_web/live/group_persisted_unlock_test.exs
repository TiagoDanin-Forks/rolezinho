defmodule RolezinhoWeb.GroupPersistedUnlockTest do
  @moduledoc """
  A signed-in user who unlocks a password-protected group should stay
  unlocked across sessions and devices: the same GitHub account never
  types the password again.

  Anonymous unlocks stay session-scoped: no accounts, no way to persist.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Group
  alias Rolezinho.Groups

  defp create_locked_group(overrides \\ %{}) do
    defaults = %{
      "name" => "Fechado",
      "slug" => "closed-#{System.unique_integer([:positive])}",
      "password" => "s3nh4",
      "visibility" => "public"
    }

    {:ok, group} = Groups.create(Map.merge(defaults, overrides))
    group
  end

  defp signed_in_conn(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
  end

  defp new_user!(login) do
    {:ok, user} =
      Accounts.find_or_create_by_github(%{
        "github_id" => System.unique_integer([:positive]),
        "github_login" => login
      })

    user
  end

  describe "signed-in user unlocks a group" do
    test "the unlock is persisted in the database", %{conn: conn} do
      user = new_user!("gh1")
      group = create_locked_group()

      # POST the right password from a signed-in session.
      signed_in_conn(conn, user)
      |> post(~p"/g/#{group.slug}/unlock", %{"password" => "s3nh4"})

      # The context now reports this user has unlocked this group.
      slugs = Groups.unlocked_slugs_for_user(user.id)
      assert MapSet.member?(slugs, group.slug)
    end

    test "next session on a fresh device sees the group as already unlocked",
         %{conn: conn} do
      user = new_user!("gh2")
      group = create_locked_group()

      # First session: unlock the group.
      signed_in_conn(conn, user)
      |> post(~p"/g/#{group.slug}/unlock", %{"password" => "s3nh4"})

      # Second session: fresh conn (no session cookie carry-over), same
      # signed-in user. The group page should render its contents, not the
      # unlock panel.
      fresh_conn = signed_in_conn(build_conn(), user)
      {:ok, view, html} = live(fresh_conn, ~p"/g/#{group.slug}")

      refute has_element?(view, "#group-unlock-form-#{group.slug}")
      assert html =~ "Fechado"
    end

    test "the unlock persists but is scoped to this specific user", %{conn: conn} do
      user_a = new_user!("owner-a")
      user_b = new_user!("owner-b")
      group = create_locked_group()

      # User A unlocks.
      signed_in_conn(conn, user_a)
      |> post(~p"/g/#{group.slug}/unlock", %{"password" => "s3nh4"})

      # User B is a different account and has not unlocked anything.
      fresh_conn = signed_in_conn(build_conn(), user_b)
      {:ok, view, _html} = live(fresh_conn, ~p"/g/#{group.slug}")
      assert has_element?(view, "#group-unlock-form-#{group.slug}")
    end

    test "re-unlocking is idempotent (no duplicate row)", %{conn: conn} do
      user = new_user!("gh-idem")
      group = create_locked_group()

      for _ <- 1..3 do
        signed_in_conn(conn, user)
        |> post(~p"/g/#{group.slug}/unlock", %{"password" => "s3nh4"})
      end

      count =
        Rolezinho.Repo.aggregate(
          from(u in Rolezinho.Group.Unlock,
            where: u.user_id == ^user.id and u.group_id == ^group.id
          ),
          :count
        )

      assert count == 1
    end

    test "a wrong password does not persist anything", %{conn: conn} do
      user = new_user!("gh-wrong")
      group = create_locked_group()

      signed_in_conn(conn, user)
      |> post(~p"/g/#{group.slug}/unlock", %{"password" => "errada"})

      assert Groups.unlocked_slugs_for_user(user.id) == MapSet.new()
    end
  end

  describe "anonymous unlocks stay session-scoped" do
    test "no signed-in user → no DB row is created", %{conn: conn} do
      group = create_locked_group()

      conn
      |> Plug.Test.init_test_session(%{})
      |> post(~p"/g/#{group.slug}/unlock", %{"password" => "s3nh4"})

      # There is no user id to key on; the DB stays empty.
      assert Rolezinho.Repo.aggregate(Rolezinho.Group.Unlock, :count) == 0
    end
  end

  describe "unlocked_slugs_for_user/1" do
    test "returns an empty MapSet for a nil user id" do
      assert Groups.unlocked_slugs_for_user(nil) == MapSet.new()
    end

    test "returns an empty MapSet for a user who has never unlocked anything" do
      user = new_user!("gh-empty")
      assert Groups.unlocked_slugs_for_user(user.id) == MapSet.new()
    end
  end

  describe "group access checks honor persisted unlocks" do
    # The user plug/on_mount merges persisted unlocks into `:unlocked_groups`
    # before `Group.accessible?/3` and `editable_by?/4` are asked, so the
    # same semantic checks work \\-\\- no new code path.

    test "an unlocked group grants access to a signed-in creator on a new device",
         %{conn: conn} do
      user = new_user!("gh-editor")
      group = create_locked_group()

      # Unlock once.
      signed_in_conn(conn, user)
      |> post(~p"/g/#{group.slug}/unlock", %{"password" => "s3nh4"})

      # On a fresh conn, the group unlock lets the user see + edit.
      fresh_conn = signed_in_conn(build_conn(), user)
      {:ok, view, html} = live(fresh_conn, ~p"/g/#{group.slug}")

      refute has_element?(view, "#group-unlock-form-#{group.slug}")

      # editable_by? is true too (the group page shows the inline edit forms).
      assert html =~ ~s(id="group-name-form")
    end
  end

  describe "Group.password_protected? sanity" do
    # A quick check the fixtures actually build password-protected groups \\-\\-
    # otherwise every test above would trivially pass for the wrong reason.
    test "seeded groups are password-protected", %{} do
      group = create_locked_group()
      assert Group.password_protected?(group)
    end
  end
end

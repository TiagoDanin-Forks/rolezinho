defmodule RolezinhoWeb.OwnerExtraPowersTest do
  @moduledoc """
  Follow-up to `OwnerEditAccessTest`: opens the last few admin-fenced
  affordances on their own event/group to the resource's own owner.

    * `EventEditLive` `set_group` — move between groups you can reach
      (unlocked or created); un-group is always allowed. Admin still
      moves to any group.
    * `GroupEditLive` `set_visibility` — an editor can flip
      public/hidden. Delete stays admin-only.
    * `EventLive` `clone` — organizer can "Repetir esse rolê" on their
      own done event.
    * `EventLive` `grow_main` / `shrink_main` — organizer can use the
      inline `+` / `−` capacity controls, matching what `resize_lists`
      on the edit page already permits.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Event
  alias Rolezinho.Events
  alias Rolezinho.Groups

  defp new_user!(login) do
    {:ok, user} =
      Accounts.find_or_create_by_github(%{
        "github_id" => System.unique_integer([:positive]),
        "github_login" => login
      })

    user
  end

  defp signed_in(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
  end

  defp create_event(overrides, opts) do
    defaults = %{
      "title" => "Rolê",
      "slug" => "e-#{System.unique_integer([:positive])}",
      "main_size" => "3",
      "wait_size" => "0"
    }

    {:ok, event} = Events.create(Map.merge(defaults, overrides), opts)
    event
  end

  describe "EventEditLive set_group" do
    test "owner can un-group their own event", %{conn: conn} do
      user = new_user!("group-owner-out")

      {:ok, group} =
        Groups.create(%{
          "name" => "Origem",
          "slug" => "og-#{System.unique_integer([:positive])}"
        })

      event =
        create_event(%{}, admin?: false, created_by_user_id: user.id, group_id: group.id)

      assert event.group_id == group.id

      {:ok, view, _html} = live(signed_in(conn, user), ~p"/admin/r/#{event.slug}/edit")
      render_change(view, "set_group", %{"group_id" => ""})

      assert Events.find(event.slug).group_id == nil
    end

    test "owner can move into a group they created", %{conn: conn} do
      user = new_user!("group-owner-mine")

      {:ok, target} =
        Groups.create(
          %{"name" => "Meu Grupo", "slug" => "mine-#{System.unique_integer([:positive])}"},
          created_by_user_id: user.id
        )

      event = create_event(%{}, admin?: false, created_by_user_id: user.id)

      {:ok, view, _html} = live(signed_in(conn, user), ~p"/admin/r/#{event.slug}/edit")
      render_change(view, "set_group", %{"group_id" => to_string(target.id)})

      assert Events.find(event.slug).group_id == target.id
    end

    test "owner CANNOT move into a group they don't have access to", %{conn: conn} do
      user = new_user!("group-owner-blocked")
      other = new_user!("stranger-group-owner")

      # A group the caller has neither created nor unlocked.
      {:ok, forbidden} =
        Groups.create(
          %{
            "name" => "Alheio",
            "slug" => "alheio-#{System.unique_integer([:positive])}",
            "password" => "s3cret"
          },
          created_by_user_id: other.id
        )

      event = create_event(%{}, admin?: false, created_by_user_id: user.id)

      {:ok, view, _html} = live(signed_in(conn, user), ~p"/admin/r/#{event.slug}/edit")

      # A hostile client can still push the event, but the server refuses.
      render_change(view, "set_group", %{"group_id" => to_string(forbidden.id)})

      assert Events.find(event.slug).group_id == nil
    end

    test "the Grupo select only shows reachable groups for a non-admin owner", %{conn: conn} do
      user = new_user!("group-owner-select")

      {:ok, mine} =
        Groups.create(
          %{"name" => "Mine", "slug" => "sel-mine-#{System.unique_integer([:positive])}"},
          created_by_user_id: user.id
        )

      {:ok, _theirs} =
        Groups.create(%{
          "name" => "Theirs",
          "slug" => "sel-theirs-#{System.unique_integer([:positive])}",
          "password" => "s"
        })

      event = create_event(%{}, admin?: false, created_by_user_id: user.id)

      {:ok, view, _html} = live(signed_in(conn, user), ~p"/admin/r/#{event.slug}/edit")

      assert has_element?(
               view,
               ~s(select#event-group-select option[value="#{mine.id}"])
             )

      # A group the caller has no access to must not be in the select.
      refute has_element?(view, ~s(select#event-group-select option), "Theirs")
    end
  end

  describe "GroupEditLive set_visibility" do
    test "owner can flip visibility on their own group", %{conn: conn} do
      user = new_user!("vis-owner")

      {:ok, group} =
        Groups.create(
          %{"name" => "Meu Grupo", "slug" => "vis-#{System.unique_integer([:positive])}"},
          created_by_user_id: user.id
        )

      {:ok, view, _html} = live(signed_in(conn, user), ~p"/admin/g/#{group.slug}/edit")
      render_click(view, "set_visibility", %{"visibility" => "hidden"})

      assert Groups.find(group.slug).visibility == :hidden
    end
  end

  describe "EventLive inline capacity controls" do
    test "owner can grow_main on their own event", %{conn: conn} do
      user = new_user!("cap-owner")
      event = create_event(%{"main_size" => "3"}, admin?: false, created_by_user_id: user.id)

      {:ok, view, _html} = live(signed_in(conn, user), ~p"/r/#{event.slug}")

      # The +/- buttons render for organizers now.
      assert has_element?(view, ~s(button[phx-click="grow_main"]))
      assert has_element?(view, ~s(button[phx-click="shrink_main"]))

      render_click(view, "grow_main")

      assert Events.find(event.slug).main_capacity == 4
    end

    test "stranger does NOT see the capacity controls and cannot use them", %{conn: conn} do
      owner = new_user!("cap-owner-strict")
      stranger = new_user!("cap-stranger")
      event = create_event(%{"main_size" => "3"}, admin?: false, created_by_user_id: owner.id)

      {:ok, view, _html} = live(signed_in(conn, stranger), ~p"/r/#{event.slug}")

      refute has_element?(view, ~s(button[phx-click="grow_main"]))
    end
  end

  describe "EventLive clone" do
    test "owner of a :done event sees the clone button and can trigger it",
         %{conn: conn} do
      user = new_user!("clone-owner")
      event = create_event(%{"slug" => "src-clone"}, admin?: false, created_by_user_id: user.id)
      {:ok, _} = Events.set_status(event, :done)

      {:ok, view, _html} = live(signed_in(conn, user), ~p"/r/#{event.slug}")

      # Button renders for the organizer (used to be admin-only).
      assert has_element?(view, ~s(button[phx-click="clone"]))

      # Clicking it fires the clone flow which push_navigates —
      # LiveViewTest signals that as a live_redirect result tuple.
      # The target is the new event's edit page under /admin/r/, so a
      # substring match on the path is enough evidence the handler
      # ran to completion.
      case render_click(view, "clone") do
        {:error, {:live_redirect, %{to: to}}} ->
          assert to =~ "/admin/r/"

        other ->
          flunk("expected a live_redirect after clone, got #{inspect(other)}")
      end

      # And a fresh event exists whose creator is the caller.
      new_clone =
        from(e in Event,
          where: e.created_by_user_id == ^user.id and e.slug != ^event.slug,
          limit: 1
        )
        |> Rolezinho.Repo.one()

      assert new_clone, "expected a clone owned by the caller to exist"
    end
  end
end

defmodule Rolezinho.GroupsTest do
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Event
  alias Rolezinho.Events
  alias Rolezinho.Group
  alias Rolezinho.Groups

  # A minimal set of params that pass `Groups.create/1`. Individual tests
  # override only the fields they care about.
  defp create_group(overrides \\ %{}) do
    defaults = %{"name" => "Vôlei", "slug" => "volei", "visibility" => "public"}
    {:ok, group} = Groups.create(Map.merge(defaults, overrides))
    group
  end

  defp create_event(group, overrides \\ %{}) do
    defaults = %{
      "title" => "Rolê",
      "slug" => "role-#{System.unique_integer([:positive])}",
      "description" => "",
      "local" => "",
      "date" => "",
      "time" => "",
      "main_size" => "3",
      "wait_size" => "0",
      "password" => ""
    }

    {:ok, event} =
      Events.create(Map.merge(defaults, overrides), admin?: true, group_id: group && group.id)

    event
  end

  describe "create/1" do
    test "creates a public group with a slug" do
      assert {:ok, %Group{} = group} =
               Groups.create(%{"name" => "Time A", "slug" => "time-a"})

      assert group.slug == "time-a"
      assert group.name == "Time A"
      assert group.visibility == :public
      assert group.password == nil
    end

    test "downcases and trims the slug" do
      {:ok, group} = Groups.create(%{"name" => "Nome ok", "slug" => "  MiXeD-Case  "})
      assert group.slug == "mixed-case"
    end

    test "rejects duplicate slugs" do
      _first = create_group(%{"slug" => "dup"})

      assert {:error, errors} = Groups.create(%{"name" => "Outro", "slug" => "dup"})
      assert errors[:slug]
    end

    test "rejects an invalid slug format" do
      assert {:error, errors} = Groups.create(%{"name" => "Nome", "slug" => "Nope Nope"})
      assert errors[:slug]
    end

    test "empty password becomes nil (no password protection)" do
      group = create_group(%{"password" => "   "})
      refute Group.password_protected?(group)
    end

    test "hidden visibility persists" do
      group = create_group(%{"slug" => "occulto", "visibility" => "hidden"})
      assert group.visibility == :hidden
    end
  end

  describe "immutable slug" do
    test "changeset ignores :slug on updates" do
      group = create_group()
      changeset = Group.changeset(group, %{slug: "other-slug", name: "Novo"})

      # `name` still applies; `slug` does not.
      assert Ecto.Changeset.get_change(changeset, :name) == "Novo"
      refute Ecto.Changeset.get_change(changeset, :slug)
    end

    test "update_name/2 does not touch slug" do
      group = create_group(%{"slug" => "keep-me"})
      {:ok, updated} = Groups.update_name(group, "Novo nome")
      assert updated.slug == "keep-me"
      assert updated.name == "Novo nome"
    end
  end

  describe "check_password/2" do
    test "returns true for a group without a password" do
      group = create_group()
      assert Groups.check_password(group, "anything")
      assert Groups.check_password(group, "")
    end

    test "returns true for the correct password" do
      group = create_group(%{"password" => "correct"})
      assert Groups.check_password(group, "correct")
    end

    test "returns false for the wrong password" do
      group = create_group(%{"password" => "correct"})
      refute Groups.check_password(group, "wrong")
    end
  end

  describe "list_public/0" do
    test "returns only public groups" do
      pub = create_group(%{"slug" => "pub"})
      _hidden = create_group(%{"slug" => "hidden-one", "visibility" => "hidden"})

      slugs = Groups.list_public() |> Enum.map(& &1.slug)
      assert pub.slug in slugs
      refute "hidden-one" in slugs
    end
  end

  describe "list_events/2" do
    setup do
      group = create_group()
      active = create_event(group, %{"slug" => "active-one"})

      {:ok, hidden_event} =
        Events.set_status(create_event(group, %{"slug" => "hidden-one"}), :hidden)

      {:ok, %{group: group, active: active, hidden: hidden_event}}
    end

    test "public visibility hides hidden events", %{group: group, hidden: hidden} do
      slugs = Groups.list_events(group, visibility: :public) |> Enum.map(& &1.slug)
      refute hidden.slug in slugs
    end

    test "with_hidden includes hidden events", %{group: group, hidden: hidden} do
      slugs = Groups.list_events(group, visibility: :with_hidden) |> Enum.map(& &1.slug)
      assert hidden.slug in slugs
    end
  end

  describe "delete/1" do
    test "marks active events as hidden and nilifies group_id" do
      group = create_group()
      event = create_event(group)

      assert event.group_id == group.id
      assert event.status == :active

      {:ok, _} = Groups.delete(group)

      # Same event still exists, but is hidden and no longer linked to a group.
      reloaded = Events.find(event.slug)
      assert reloaded.status == :hidden
      assert reloaded.group_id == nil
    end

    test "leaves already-done events alone (only status change is active/payments_only → hidden)" do
      group = create_group()
      event = create_event(group)
      {:ok, event} = Events.set_status(event, :done)

      {:ok, _} = Groups.delete(group)

      reloaded = Events.find(event.slug)
      assert reloaded.status == :done
      assert reloaded.group_id == nil
    end
  end

  describe "editable_by? / accessible?" do
    test "admin can do everything" do
      unlocked = MapSet.new()

      pub = create_group()
      priv = create_group(%{"slug" => "p", "password" => "s"})

      assert Group.accessible?(pub, true, unlocked)
      assert Group.accessible?(priv, true, unlocked)
      assert Group.editable_by?(pub, true, unlocked)
      assert Group.editable_by?(priv, true, unlocked)
    end

    test "passwordless group: anyone accessible, only admin editable" do
      pub = create_group()
      unlocked = MapSet.new([pub.slug])

      # Public group is accessible to everyone; unlocked_groups doesn't matter.
      assert Group.accessible?(pub, false, MapSet.new())
      assert Group.accessible?(pub, false, unlocked)

      # But non-admin cannot edit it, even if slug is in unlocked_groups.
      refute Group.editable_by?(pub, false, unlocked)
    end

    test "password-protected group: unlock in session gates access + edit" do
      priv = create_group(%{"slug" => "priv", "password" => "s"})

      refute Group.accessible?(priv, false, MapSet.new())
      refute Group.editable_by?(priv, false, MapSet.new())

      unlocked = MapSet.new([priv.slug])
      assert Group.accessible?(priv, false, unlocked)
      assert Group.editable_by?(priv, false, unlocked)
    end

    test "password-protected group: signed-in creator bypasses the unlock check" do
      priv = create_group(%{"slug" => "priv2", "password" => "s"})
      priv = %{priv | created_by_user_id: 42}

      # No entry in `unlocked_groups`, but the creator id matches — access granted.
      assert Group.accessible?(priv, false, MapSet.new(), 42)
      assert Group.editable_by?(priv, false, MapSet.new(), 42)

      # A different signed-in user still needs the unlock.
      refute Group.accessible?(priv, false, MapSet.new(), 7)
      refute Group.editable_by?(priv, false, MapSet.new(), 7)
    end

    test "anonymous viewer (nil user_id) keeps the old three-arg semantics" do
      priv = create_group(%{"slug" => "priv3", "password" => "s"})

      refute Group.accessible?(priv, false, MapSet.new(), nil)
      assert Group.accessible?(priv, false, MapSet.new([priv.slug]), nil)
    end
  end

  describe "events.list_open/0 with groups" do
    test "excludes events belonging to any group" do
      group = create_group()
      _grouped = create_event(group, %{"slug" => "grouped-1"})
      ungrouped = create_event(nil, %{"slug" => "ungrouped-1"})

      slugs = Events.list_open() |> Enum.map(& &1.slug)
      assert "ungrouped-1" in slugs
      refute "grouped-1" in slugs
      assert ungrouped.slug == "ungrouped-1"
    end
  end

  describe "events.set_group/2" do
    test "admin move: event moves and reappears without the old group" do
      group_a = create_group(%{"slug" => "ga"})
      group_b = create_group(%{"slug" => "gb"})

      event = create_event(group_a)
      assert event.group_id == group_a.id

      {:ok, moved} = Events.set_group(event, group_b.id)
      assert moved.group_id == group_b.id

      # And nilifying works too.
      {:ok, orphan} = Events.set_group(moved, nil)
      assert orphan.group_id == nil
    end
  end

  describe "mass assignment safety" do
    test "Event.changeset ignores :group_id from casted params" do
      changeset = Event.changeset(%Event{}, %{group_id: 999})
      refute Ecto.Changeset.get_change(changeset, :group_id)
    end
  end
end

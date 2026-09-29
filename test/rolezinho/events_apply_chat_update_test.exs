defmodule Rolezinho.EventsApplyChatUpdateTest do
  @moduledoc """
  Context coverage for `Events.apply_chat_update/2` and
  `Events.list_updatable_for/2` — the two new context surfaces the
  `/atualizar` LiveView leans on.

  What we lock in:

    * `list_updatable_for/2` filters to open statuses (`:active`,
      `:maybe`), owner-scoped for normal users and world-wide for
      admin, ordered by `updated_at desc`.
    * `apply_chat_update/2` clears / updates / replaces rows per the
      merge rules documented on that function.
    * Identity preservation: an unchanged name keeps the row's
      `participant_id`; a changed name drops it.
    * `values` are additive — an update to one key preserves the
      others.
    * `add_fields` runs before row updates, so a row that references
      a newly added field lands with that field recognized.
    * `remove_field_ids` tolerates `:not_found`.
  """
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Events

  defp create_event(overrides \\ %{}) do
    n = System.unique_integer([:positive])

    defaults = %{
      "title" => "Vôlei",
      "slug" => "chat-update-#{n}",
      "description" => "",
      "main_size" => "4",
      "wait_size" => "0"
    }

    {:ok, event} = Events.create(Map.merge(defaults, overrides), admin?: true)
    event
  end

  defp add_row(event, name, opts \\ []) do
    participant_id = Keyword.get(opts, :participant_id, "tok-#{name}")
    values = Keyword.get(opts, :values, %{})

    {:ok, event, _} =
      Events.add_party(event, name, 1, participant_id: participant_id, values: values)

    event
  end

  defp with_field(event, label) do
    {:ok, event} = Events.add_form_field(event, %{"label" => label})
    event
  end

  describe "list_updatable_for/2" do
    setup do
      # Two users: `owner` created two events, `other` created one.
      # An admin flag flips the query wide.
      {:ok, owner} =
        Rolezinho.Accounts.register_user(%{
          "username" => "owner#{System.unique_integer([:positive])}",
          "password" => "supersecret"
        })

      {:ok, other} =
        Rolezinho.Accounts.register_user(%{
          "username" => "other#{System.unique_integer([:positive])}",
          "password" => "supersecret"
        })

      {:ok, e1} =
        Events.create(
          %{
            "title" => "R1",
            "slug" => "r1-#{System.unique_integer([:positive])}",
            "main_size" => "3",
            "wait_size" => "0"
          },
          created_by_user_id: owner.id
        )

      {:ok, e2} =
        Events.create(
          %{
            "title" => "R2",
            "slug" => "r2-#{System.unique_integer([:positive])}",
            "main_size" => "3",
            "wait_size" => "0"
          },
          created_by_user_id: owner.id
        )

      {:ok, e3} =
        Events.create(
          %{
            "title" => "R3",
            "slug" => "r3-#{System.unique_integer([:positive])}",
            "main_size" => "3",
            "wait_size" => "0"
          },
          created_by_user_id: other.id
        )

      %{owner: owner, other: other, e1: e1, e2: e2, e3: e3}
    end

    test "nil user_id yields []" do
      assert Events.list_updatable_for(nil) == []
    end

    test "owner sees only their events", %{owner: owner, e1: e1, e2: e2} do
      slugs = owner.id |> Events.list_updatable_for() |> Enum.map(& &1.slug)

      # Both belong to the owner and are :active — both listed.
      assert e1.slug in slugs
      assert e2.slug in slugs
      # The other user's event is not.
      refute Enum.any?(slugs, &String.starts_with?(&1, "r3-"))
    end

    test "admin: true widens the query to every editable event",
         %{owner: owner, e1: e1, e2: e2, e3: e3} do
      slugs =
        owner.id
        |> Events.list_updatable_for(admin?: true)
        |> Enum.map(& &1.slug)

      assert e1.slug in slugs
      assert e2.slug in slugs
      assert e3.slug in slugs
    end

    test ":done and :payments_only are excluded",
         %{owner: owner, e1: e1, e2: e2} do
      {:ok, _} = Events.set_status(e1, :done)
      {:ok, _} = Events.set_status(e2, :payments_only)

      assert Events.list_updatable_for(owner.id) == []
    end

    test ":maybe events are included", %{owner: owner, e1: e1, e2: e2} do
      # Close e2 so this assertion has a single-element list to match on.
      {:ok, _} = Events.set_status(e2, :done)
      {:ok, _} = Events.set_status(e1, :maybe)

      assert [%{slug: slug}] = Events.list_updatable_for(owner.id)
      assert slug == e1.slug
    end

    test "ordered by updated_at desc — most-recently-touched first",
         %{owner: owner, e1: e1, e2: e2} do
      # Touch e1 last so it should sort first.
      {:ok, _} = Events.set_status(e2, :maybe)
      Process.sleep(1_100)
      {:ok, _} = Events.set_status(e1, :maybe)

      assert [%{slug: first} | _] = Events.list_updatable_for(owner.id)
      assert first == e1.slug
    end
  end

  describe "apply_chat_update/2 — clearing" do
    test "empty name clears the slot" do
      event = create_event() |> add_row("Alice")

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main: %{1 => %{"name" => ""}}
               })

      [first | _] = updated.main_list
      assert first.name == ""
      assert first.participant_id == nil
    end
  end

  describe "apply_chat_update/2 — in-place updates" do
    test "same name → preserves participant_id, updates values/paid" do
      event =
        create_event()
        |> with_field("Camisa")
        |> add_row("Alice", participant_id: "tok-alice", values: %{"camisa" => "M"})

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main: %{
                   1 => %{"name" => "Alice", "values" => %{"camisa" => "G"}, "paid" => true}
                 }
               })

      [first | _] = updated.main_list
      assert first.name == "Alice"
      assert first.participant_id == "tok-alice"
      assert first.values == %{"camisa" => "G"}
      assert first.paid == true
    end

    test "case + accent-insensitive name equality still counts as same person" do
      event =
        create_event()
        |> add_row("João", participant_id: "tok-joao")

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main: %{1 => %{"name" => "joao ", "paid" => true}}
               })

      [first | _] = updated.main_list
      # Identity preserved.
      assert first.participant_id == "tok-joao"
      assert first.paid == true
    end

    test "an absent name doesn't wipe the row — only the sent fields change" do
      event =
        create_event()
        |> with_field("Camisa")
        |> add_row("Alice", participant_id: "tok-alice", values: %{"camisa" => "M"})

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main: %{1 => %{"paid" => true}}
               })

      [first | _] = updated.main_list
      assert first.name == "Alice"
      assert first.paid == true
      # Values untouched — nil name means "update in place" and the
      # values-key wasn't included at all.
      assert first.values == %{"camisa" => "M"}
    end

    test "values updates merge additively" do
      # Deliberately accent-free labels so the field ids come out
      # as-typed (`Rolezinho.Event.FormField.build_id/2` strips
      # accents in a way that turns `ú` → `u-`, which would
      # obscure what this test is actually asserting).
      event =
        create_event()
        |> with_field("Camisa")
        |> with_field("Numero")
        |> add_row("Alice",
          participant_id: "tok-alice",
          values: %{"camisa" => "M", "numero" => "10"}
        )

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main: %{1 => %{"name" => "Alice", "values" => %{"numero" => "7"}}}
               })

      [first | _] = updated.main_list
      # `numero` overridden, `camisa` preserved.
      assert first.values == %{"camisa" => "M", "numero" => "7"}
    end
  end

  describe "apply_chat_update/2 — replacements" do
    test "different name replaces the slot and drops identity" do
      event =
        create_event()
        |> add_row("Alice", participant_id: "tok-alice")

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main: %{1 => %{"name" => "Bruno", "paid" => true}}
               })

      [first | _] = updated.main_list
      assert first.name == "Bruno"
      assert first.participant_id == nil
      assert first.user_id == nil
      assert first.paid == true
      assert first.joined_at != nil
    end

    test "new attendee lands on an empty slot" do
      event = create_event()

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main: %{2 => %{"name" => "Carlos"}}
               })

      [_slot1, slot2 | _] = updated.main_list
      assert slot2.name == "Carlos"
      # Fresh row, no identity attached.
      assert slot2.participant_id == nil
    end
  end

  describe "apply_chat_update/2 — form fields" do
    test "add_fields runs before row updates so a new key is recognized" do
      event = create_event() |> add_row("Alice", participant_id: "tok-alice")

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 add_fields: [%{"label" => "Tamanho"}],
                 main: %{1 => %{"name" => "Alice", "values" => %{"tamanho" => "M"}}}
               })

      # Field is now on the event…
      assert Enum.any?(updated.form_fields, &(&1.id == "tamanho"))

      # …and the row's value landed.
      [first | _] = updated.main_list
      assert Map.get(first.values, "tamanho") == "M"
    end

    test "remove_field_ids tolerates a missing field" do
      event = create_event() |> add_row("Alice")

      assert {:ok, _updated} =
               Events.apply_chat_update(event, %{
                 remove_field_ids: ["never-existed"],
                 main: %{}
               })
    end

    test "values naming an unknown field are silently dropped" do
      event = create_event() |> add_row("Alice", participant_id: "tok-alice")

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main: %{1 => %{"name" => "Alice", "values" => %{"nope" => "x"}}}
               })

      [first | _] = updated.main_list
      # The unknown key never made it to the attendee.
      assert first.values == %{}
    end
  end

  describe "apply_chat_update/2 — capacity" do
    test "growing: capacity bumps up and new named rows land on the fresh slots" do
      event = create_event(%{"main_size" => "4"}) |> add_row("Alice")

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main_capacity: 6,
                 main: %{5 => %{"name" => "Bruno"}, 6 => %{"name" => "Carla"}}
               })

      assert updated.main_capacity == 6
      assert length(updated.main_list) == 6
      # Alice still at slot 1, new folks at 5 and 6.
      assert Enum.at(updated.main_list, 0).name == "Alice"
      assert Enum.at(updated.main_list, 4).name == "Bruno"
      assert Enum.at(updated.main_list, 5).name == "Carla"
    end

    test "growing implicitly when a proposal row is past the current capacity" do
      # No `main_capacity` set — but slot 5 is past the capacity of 4,
      # so the grow-pre-pass expands to fit.
      event = create_event(%{"main_size" => "4"})

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main: %{5 => %{"name" => "Carla"}}
               })

      assert updated.main_capacity == 5
      assert Enum.at(updated.main_list, 4).name == "Carla"
    end

    test "shrinking: clears + capacity drop combine to remove trailing slots" do
      # Start with a 5-slot event and only 2 filled rows.
      event =
        create_event(%{"main_size" => "5"})
        |> add_row("Alice")
        |> add_row("Bruno")

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main_capacity: 2,
                 main: %{1 => %{"name" => "Alice"}, 2 => %{"name" => "Bruno"}}
               })

      assert updated.main_capacity == 2
      assert length(updated.main_list) == 2
    end

    test "shrink attempt below filled count clamps at filled" do
      # No one gets silently dropped even when the URL asks for it.
      event =
        create_event(%{"main_size" => "4"})
        |> add_row("Alice")
        |> add_row("Bruno")
        |> add_row("Carla")

      assert {:ok, updated} =
               Events.apply_chat_update(event, %{
                 main_capacity: 1,
                 main: %{}
               })

      # Alice / Bruno / Carla all still on the list — capacity
      # clamped at 3, not 1.
      assert updated.main_capacity == 3
      names = updated.main_list |> Enum.map(& &1.name) |> Enum.filter(&(&1 != ""))
      assert Enum.sort(names) == ["Alice", "Bruno", "Carla"]
    end
  end
end

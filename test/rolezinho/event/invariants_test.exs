defmodule Rolezinho.Event.InvariantsTest do
  @moduledoc """
  The six invariants the product spec marks as never allowed to break.

  These are not feature tests: each one is a property of the data that has to
  survive whatever sequence of operations reaches it. If one of these fails, a
  list is lying about who is in it.
  """
  use ExUnit.Case, async: true

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee

  # A slot exists even while empty (RN-01), so a list is always as long as its
  # capacity. Building one any other way would test a shape the app never
  # produces.
  defp event(attrs) do
    capacity = Map.get(attrs, :main_capacity, 4)

    defaults = %{
      slug: "volei",
      status: :active,
      main_capacity: capacity,
      main_list: empty_slots(capacity),
      # The waiting list grows by appending rather than filling reserved slots
      # (RN-33: the queue never turns anyone away), so it starts empty.
      wait_list: [],
      wait_enabled: true
    }

    struct(Event, Map.merge(defaults, attrs))
  end

  defp empty_slots(n), do: for(_ <- 1..n//1, do: %Attendee{name: "", paid: false})

  defp filled(list), do: Enum.count(list, &(match?(%Attendee{}, &1) and &1.name != ""))

  describe "a list never exceeds its capacity" do
    test "joining stops at the last slot" do
      event = event(%{main_capacity: 2})

      {:ok, event} = Event.add_to_main(event, "Marcia")
      {:ok, event} = Event.add_to_main(event, "Roberta")

      assert filled(event.main_list) == 2
      assert {:error, :main_full} = Event.add_to_main(event, "Henrique")
    end

    test "the overflow goes to the waiting list rather than being refused" do
      event = event(%{main_capacity: 1})

      {:ok, event} = Event.add_to_main(event, "Marcia")
      assert {:error, :main_full} = Event.add_to_main(event, "Roberta")
      assert {:ok, event} = Event.add_to_wait(event, "Roberta")

      assert filled(event.wait_list) == 1
    end
  end

  describe "removing frees a slot without losing anyone" do
    # RN-01 asks for a slot to be a fixed position, so that removing someone
    # leaves a gap at their number. The list currently compacts instead: the
    # names below move up and the free slot lands at the end. Nobody is lost
    # either way, which is what this invariant is about; the numbering
    # difference is tracked in TODOS.md and belongs to the v2 join flow.
    test "everyone else survives a removal" do
      event = event(%{main_capacity: 3})

      {:ok, event} = Event.add_to_main(event, "Marcia")
      {:ok, event} = Event.add_to_main(event, "Roberta")
      {:ok, event} = Event.add_to_main(event, "Henrique")

      event = Event.remove_main(event, 2)

      names = event.main_list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))
      assert names == ["Marcia", "Henrique"]
    end

    test "the list keeps its capacity after a removal" do
      event = event(%{main_capacity: 3})

      {:ok, event} = Event.add_to_main(event, "Marcia")
      event = Event.remove_main(event, 1)

      assert length(event.main_list) == 3
      assert filled(event.main_list) == 0
    end

    test "a freed slot is reused by the next person to join" do
      event = event(%{main_capacity: 3})

      {:ok, event} = Event.add_to_main(event, "Marcia")
      {:ok, event} = Event.add_to_main(event, "Roberta")
      event = Event.remove_main(event, 1)

      {:ok, event} = Event.add_to_main(event, "Henrique")

      names = event.main_list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))
      assert Enum.sort(names) == ["Henrique", "Roberta"]
      assert filled(event.main_list) == 2
    end
  end

  describe "a paid check only exists on a filled slot" do
    test "an empty slot never carries a check" do
      event = event(%{main_capacity: 2})

      {:ok, event} = Event.add_to_main(event, "Marcia")
      event = Event.toggle_paid_main(event, 1)

      refute Enum.any?(event.main_list, fn slot -> slot.name == "" and slot.paid end)
    end

    test "removing someone clears the check with them" do
      event = event(%{main_capacity: 2})

      {:ok, event} = Event.add_to_main(event, "Marcia")
      event = Event.toggle_paid_main(event, 1)
      assert Enum.at(event.main_list, 0).paid

      event = Event.remove_main(event, 1)

      refute Enum.any?(event.main_list, & &1.paid)
    end
  end

  describe "nobody confirmed is dropped by a resize" do
    test "shrinking below the number of people is refused" do
      event = event(%{main_capacity: 3})

      {:ok, event} = Event.add_to_main(event, "Marcia")
      {:ok, event} = Event.add_to_main(event, "Roberta")
      {:ok, event} = Event.add_to_main(event, "Henrique")

      resized = Event.resize_main(event, 1)

      assert filled(resized.main_list) == 3
    end

    test "shrinking removes empty slots only" do
      event = event(%{main_capacity: 4})

      {:ok, event} = Event.add_to_main(event, "Marcia")
      resized = Event.resize_main(event, 2)

      assert length(resized.main_list) == 2
      assert Enum.at(resized.main_list, 0).name == "Marcia"
    end

    test "growing is always allowed" do
      event = event(%{main_capacity: 2})

      {:ok, event} = Event.add_to_main(event, "Marcia")
      resized = Event.resize_main(event, 6)

      assert length(resized.main_list) == 6
      assert filled(resized.main_list) == 1
    end
  end

  describe "a promoted person arrives unpaid (RN-32)" do
    test "promotion never carries a check across from the waiting list" do
      event = event(%{main_capacity: 2})

      {:ok, event} = Event.add_to_main(event, "Marcia")
      {:ok, event} = Event.add_to_wait(event, "Rivanete")

      {:ok, event} = Event.promote(event, 1)

      promoted = Enum.find(event.main_list, &(&1.name == "Rivanete"))
      assert promoted
      refute promoted.paid
    end
  end

  describe "identity travels with the row" do
    test "the joining participant's id lands on the row they occupy" do
      event = event(%{main_capacity: 2})

      {:ok, event} = Event.add_to_main(event, "Marcia", participant_id: "abc123")

      assert Enum.at(event.main_list, 0) |> Attendee.owned_by?("abc123")
    end

    test "a row created without an id is claimable by nobody" do
      event = event(%{main_capacity: 2})

      {:ok, event} = Event.add_to_main(event, "Marcia")

      refute Enum.at(event.main_list, 0) |> Attendee.owned_by?("abc123")
    end

    test "joining records when it happened" do
      event = event(%{main_capacity: 2})

      {:ok, event} = Event.add_to_main(event, "Marcia", participant_id: "abc123")

      assert %DateTime{} = Enum.at(event.main_list, 0).joined_at
    end
  end
end

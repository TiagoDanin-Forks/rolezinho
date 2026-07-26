defmodule Rolezinho.Event.PartyTest do
  @moduledoc """
  RN-04: companions join as rows of their own.

  A slot holds one person, so a party of three occupies three positions. A
  single row reading "Márcia +2" would let three people sit in one place and
  every count on the screen would be wrong.
  """
  use ExUnit.Case, async: true

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee

  defp event(attrs) do
    capacity = Map.get(attrs, :main_capacity, 6)

    defaults = %{
      slug: "volei",
      status: :active,
      main_capacity: capacity,
      main_list: for(_ <- 1..capacity//1, do: %Attendee{name: "", paid: false}),
      wait_list: [],
      wait_enabled: true
    }

    struct(Event, Map.merge(defaults, attrs))
  end

  defp names(list), do: list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))

  describe "a party of one" do
    test "is just the person" do
      assert {:ok, event, placed} = Event.add_party(event(%{}), "Márcia", 1)

      assert names(event.main_list) == ["Márcia"]
      assert placed == %{main: 1, wait: 0}
    end
  end

  describe "a party of several" do
    test "takes one row per person" do
      assert {:ok, event, placed} = Event.add_party(event(%{}), "Márcia", 3)

      assert names(event.main_list) == ["Márcia", "Convidado de Márcia", "Convidado de Márcia"]
      assert placed == %{main: 3, wait: 0}
    end

    test "names companions after whoever brought them" do
      {:ok, event, _} = Event.add_party(event(%{}), "Márcia", 2)

      # Who owes for the extra seat is readable from the row itself.
      assert Enum.at(event.main_list, 1).name == "Convidado de Márcia"
    end

    test "shares one identity across the whole party" do
      {:ok, event, _} = Event.add_party(event(%{}), "Márcia", 3, participant_id: "abc")

      # One browser joined, so one person can act on all three rows.
      assert Enum.count(event.main_list, &Attendee.owned_by?(&1, "abc")) == 3
    end

    test "arrives unpaid" do
      {:ok, event, _} = Event.add_party(event(%{}), "Márcia", 3)

      refute Enum.any?(event.main_list, & &1.paid)
    end
  end

  describe "a party larger than the room left" do
    test "splits across both lists in one action" do
      assert {:ok, event, placed} = Event.add_party(event(%{main_capacity: 2}), "Márcia", 4)

      assert placed == %{main: 2, wait: 2}
      assert length(names(event.main_list)) == 2
      assert length(names(event.wait_list)) == 2
    end

    test "keeps the person themselves in the main list" do
      {:ok, event, _} = Event.add_party(event(%{main_capacity: 1}), "Márcia", 3)

      # The overflow is companions, not the person who joined.
      assert names(event.main_list) == ["Márcia"]
    end

    test "goes entirely to the queue when the list is already full" do
      full = event(%{main_capacity: 1})
      {:ok, full} = Event.add_to_main(full, "Ana")

      assert {:ok, event, placed} = Event.add_party(full, "Márcia", 2)

      assert placed == %{main: 0, wait: 2}
      assert Enum.map(event.wait_list, & &1.name) == ["Márcia", "Convidado de Márcia"]
    end
  end

  describe "without a waiting list" do
    test "a party that does not fit is refused rather than half-admitted" do
      no_queue = event(%{main_capacity: 2, wait_enabled: false})

      # Taking two and dropping the third silently would leave someone believing
      # their friend is in.
      assert {:error, :party_does_not_fit} = Event.add_party(no_queue, "Márcia", 3)
    end

    test "a party that fits exactly is accepted" do
      no_queue = event(%{main_capacity: 3, wait_enabled: false})

      assert {:ok, event, %{main: 3, wait: 0}} = Event.add_party(no_queue, "Márcia", 3)
      assert length(names(event.main_list)) == 3
    end

    test "a full list refuses" do
      no_queue = event(%{main_capacity: 1, wait_enabled: false})
      {:ok, no_queue} = Event.add_to_main(no_queue, "Ana")

      assert {:error, :main_full} = Event.add_party(no_queue, "Márcia", 1)
    end
  end

  describe "rejections" do
    test "an empty name" do
      assert {:error, :empty_name} = Event.add_party(event(%{}), "   ", 2)
    end

    test "a party of zero or a negative size" do
      assert {:error, :invalid_party_size} = Event.add_party(event(%{}), "Márcia", 0)
      assert {:error, :invalid_party_size} = Event.add_party(event(%{}), "Márcia", -1)
    end

    test "a party beyond the allowance" do
      # Someone bringing more than nine people is organizing their own event.
      assert {:error, :invalid_party_size} = Event.add_party(event(%{}), "Márcia", 10)
    end
  end

  describe "the capacity invariant still holds" do
    test "a party never overfills the list" do
      {:ok, event, _} = Event.add_party(event(%{main_capacity: 3}), "Márcia", 9)

      assert length(event.main_list) == 3
      assert length(names(event.main_list)) == 3
    end
  end
end

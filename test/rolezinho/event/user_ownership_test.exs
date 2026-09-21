defmodule Rolezinho.Event.UserOwnershipTest do
  @moduledoc """
  ADR-0002: a signed-in user who joins a rolezinho gets their `user_id` on
  the row alongside the per-device `participant_id`. Either identity is
  sufficient to prove ownership afterwards — the token identifies a
  device, the user id identifies a person. The two together mean the
  same person can act on their row from any device they sign into with
  the same GitHub account, even after cookies are cleared.
  """
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee
  alias Rolezinho.Event.Policy

  defp base_event do
    %Event{
      title: "Vôlei",
      slug: "volei",
      status: :active,
      main_capacity: 3,
      main_list: for(_ <- 1..3, do: %Attendee{name: "", paid: false}),
      wait_enabled: true,
      wait_list: []
    }
  end

  describe "Attendee.owns?/3" do
    test "matches when the participant_id matches" do
      attendee = %Attendee{participant_id: "tok"}
      assert Attendee.owns?(attendee, "tok", nil)
    end

    test "matches when the user_id matches" do
      attendee = %Attendee{user_id: 42}
      assert Attendee.owns?(attendee, nil, 42)
    end

    test "matches when both match" do
      attendee = %Attendee{participant_id: "tok", user_id: 42}
      assert Attendee.owns?(attendee, "tok", 42)
    end

    test "does not match on a nil-vs-nil row" do
      # A row with no identity is not claimable by a caller sending no
      # identity either — that would let anyone with an empty session act
      # on grandfathered rows.
      refute Attendee.owns?(%Attendee{}, nil, nil)
      refute Attendee.owns?(%Attendee{}, "", nil)
    end

    test "user_id mismatch does not claim the row" do
      attendee = %Attendee{user_id: 42}
      refute Attendee.owns?(attendee, nil, 43)
    end
  end

  describe "add_to_main/3 with user_id" do
    test "the row carries both identities when both are supplied" do
      {:ok, event} =
        Event.add_to_main(base_event(), "Alice", participant_id: "tok", user_id: 42)

      row = Enum.at(event.main_list, 0)
      assert row.name == "Alice"
      assert row.participant_id == "tok"
      assert row.user_id == 42
    end

    test "user_id alone (anonymous session, no token) still identifies the row" do
      {:ok, event} = Event.add_to_main(base_event(), "Bob", user_id: 42)

      row = Enum.at(event.main_list, 0)
      assert row.user_id == 42
      assert is_nil(row.participant_id)
      assert Attendee.owns?(row, nil, 42)
    end
  end

  describe "add_party/4 shares the user id across the party (RN-04)" do
    test "every row of the party carries the same user_id" do
      {:ok, event, _placed} =
        Event.add_party(base_event(), "Márcia", 3, participant_id: "tok", user_id: 42)

      # Same person joined bringing two friends: all three rows are theirs
      # to manage, both via the token and via the user id.
      assert Enum.count(event.main_list, &Attendee.owns?(&1, "tok", nil)) == 3
      assert Enum.count(event.main_list, &Attendee.owns?(&1, nil, 42)) == 3
    end
  end

  describe "Policy: signed-in user acts on their row without the token" do
    setup do
      # Alice joins with both identities.
      {:ok, event} =
        Event.add_to_main(base_event(), "Alice", participant_id: "tok-alice", user_id: 42)

      %{event: event, row: Enum.at(event.main_list, 0)}
    end

    test "same user, no token → can toggle paid + remove", %{event: event, row: row} do
      opts = [participant_id: nil, current_user_id: 42]
      assert Policy.can_toggle_paid?(event, row, opts)
      assert Policy.can_remove?(event, row, opts)
      assert Policy.role(event, opts) == :participant
    end

    test "same token, no user → can toggle paid + remove", %{event: event, row: row} do
      opts = [participant_id: "tok-alice", current_user_id: nil]
      assert Policy.can_toggle_paid?(event, row, opts)
      assert Policy.can_remove?(event, row, opts)
      assert Policy.role(event, opts) == :participant
    end

    test "different user, different token → cannot", %{event: event, row: row} do
      opts = [participant_id: "tok-someone-else", current_user_id: 99]
      refute Policy.can_toggle_paid?(event, row, opts)
      refute Policy.can_remove?(event, row, opts)
      assert Policy.role(event, opts) == :visitor
    end

    test "grandfathered row (no ids on the row): no visitor claims it via user_id",
         %{event: event} do
      {:ok, event} = Event.add_to_main(event, "Grandfather")
      grandfather = Enum.find(event.main_list, &(&1.name == "Grandfather"))

      opts = [participant_id: nil, current_user_id: 42]
      refute Policy.can_toggle_paid?(event, grandfather, opts)
      refute Policy.can_remove?(event, grandfather, opts)
    end
  end
end

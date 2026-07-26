defmodule Rolezinho.Event.PolicyTest do
  @moduledoc """
  The permission matrix from the product spec, asserted row by row.

  These are the rules a screen must not be trusted to enforce on its own: a
  socket message can be sent without the button that would have produced it, so
  every one of these has to hold on the server.
  """
  use ExUnit.Case, async: true

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee
  alias Rolezinho.Event.Policy

  @me "participant-abc"
  @someone_else "participant-xyz"

  defp event(attrs \\ %{}) do
    defaults = %{
      slug: "volei",
      status: :active,
      organizer_token: "organizer-secret",
      main_capacity: 3,
      main_list: [
        %Attendee{name: "Marcia", participant_id: @someone_else},
        %Attendee{name: "Eu", participant_id: @me}
      ],
      wait_list: []
    }

    struct(Event, Map.merge(defaults, attrs))
  end

  defp my_row(event), do: Enum.find(event.main_list, &Attendee.owned_by?(&1, @me))
  defp their_row(event), do: Enum.find(event.main_list, &Attendee.owned_by?(&1, @someone_else))

  defp as_visitor, do: []
  defp as_participant, do: [participant_id: @me]
  defp as_organizer, do: [organizer?: true]
  defp as_admin, do: [admin?: true]

  describe "role/2" do
    test "someone with no claim is a visitor" do
      assert Policy.role(event(), as_visitor()) == :visitor
    end

    test "holding a row makes someone a participant" do
      assert Policy.role(event(), as_participant()) == :participant
    end

    test "holding the event token makes someone the organizer" do
      assert Policy.role(event(), as_organizer()) == :organizer
    end

    test "the environment-wide bypass outranks the rest" do
      assert Policy.role(event(), as_admin()) == :admin
    end

    test "an id that matches no row does not confer participant" do
      assert Policy.role(event(), participant_id: "nobody") == :visitor
    end
  end

  describe "can_toggle_paid?/3 (RN-12, RN-13)" do
    test "a participant marks their own row" do
      event = event()

      assert Policy.can_toggle_paid?(event, my_row(event), as_participant())
    end

    test "a participant cannot mark somebody else's row" do
      event = event()

      refute Policy.can_toggle_paid?(event, their_row(event), as_participant())
    end

    test "the organizer marks any row, being the one who sees the money arrive" do
      event = event()

      assert Policy.can_toggle_paid?(event, my_row(event), as_organizer())
      assert Policy.can_toggle_paid?(event, their_row(event), as_organizer())
    end

    test "a visitor marks nothing" do
      event = event()

      refute Policy.can_toggle_paid?(event, my_row(event), as_visitor())
      refute Policy.can_toggle_paid?(event, their_row(event), as_visitor())
    end
  end

  describe "can_remove?/3 (RN-21)" do
    test "a participant removes only themselves" do
      event = event()

      assert Policy.can_remove?(event, my_row(event), as_participant())
      refute Policy.can_remove?(event, their_row(event), as_participant())
    end

    test "the organizer removes anyone" do
      event = event()

      assert Policy.can_remove?(event, their_row(event), as_organizer())
    end

    test "a visitor removes nobody" do
      event = event()

      refute Policy.can_remove?(event, my_row(event), as_visitor())
    end
  end

  describe "can_edit?/2 and can_promote?/2 (RN-23, RN-31)" do
    test "editing details belongs to the organizer" do
      refute Policy.can_edit?(event(), as_visitor())
      refute Policy.can_edit?(event(), as_participant())
      assert Policy.can_edit?(event(), as_organizer())
      assert Policy.can_edit?(event(), as_admin())
    end

    test "promoting from the waiting list belongs to the organizer" do
      refute Policy.can_promote?(event(), as_visitor())
      refute Policy.can_promote?(event(), as_participant())
      assert Policy.can_promote?(event(), as_organizer())
    end
  end

  describe "can_join?/2" do
    test "an open event accepts anyone" do
      assert Policy.can_join?(event(), as_visitor())
    end

    test "a closed event accepts nobody, not even the organizer" do
      closed = event(%{status: :done})

      refute Policy.can_join?(closed, as_visitor())
      refute Policy.can_join?(closed, as_organizer())
      refute Policy.can_join?(closed, as_admin())
    end

    test "a payments-only event stops signups but not the organizer" do
      locked = event(%{status: :payments_only})

      refute Policy.can_join?(locked, as_visitor())
      assert Policy.can_join?(locked, as_organizer())
    end
  end
end

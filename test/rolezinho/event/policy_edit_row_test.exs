defmodule Rolezinho.Event.PolicyEditRowTest do
  @moduledoc """
  `can_edit_row?/3` \u2014 who may fix a name or answer on a row.

  Same permission set as `can_remove?/3` today (admin, organizer, or the
  row's own owner by either identity), but kept as a dedicated function so
  the two decisions can diverge later without one bug becoming two.
  """
  use ExUnit.Case, async: true

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee
  alias Rolezinho.Event.Policy

  defp event, do: %Event{main_list: [], wait_list: []}

  defp row(overrides \\ %{}) do
    struct(
      %Attendee{
        name: "Alice",
        participant_id: "tok-alice",
        user_id: nil
      },
      overrides
    )
  end

  test "admin can edit any row" do
    assert Policy.can_edit_row?(event(), row(), admin?: true)
  end

  test "organizer can edit any row" do
    assert Policy.can_edit_row?(event(), row(), organizer?: true)
  end

  test "signed-in creator resolves to :organizer and may edit" do
    ev = %{event() | created_by_user_id: 42}
    assert Policy.can_edit_row?(ev, row(), current_user_id: 42)
  end

  test "row owner by participant_id may edit their own row" do
    ev = %{event() | main_list: [row()]}
    assert Policy.can_edit_row?(ev, row(), participant_id: "tok-alice")
  end

  test "row owner by user_id may edit their own row" do
    r = row(%{participant_id: nil, user_id: 7})
    ev = %{event() | main_list: [r]}
    assert Policy.can_edit_row?(ev, r, current_user_id: 7)
  end

  test "a stranger with no identity is a visitor and may not edit" do
    ev = %{event() | main_list: [row()]}
    refute Policy.can_edit_row?(ev, row(), [])
  end

  test "a participant on the event but not this row may NOT edit somebody else's row" do
    other = row(%{name: "Beto", participant_id: "tok-beto"})
    ev = %{event() | main_list: [row(), other]}
    # Alice holds her own row \u2014 that makes her a participant on the event, but
    # she is not authorized to edit Beto's row.
    refute Policy.can_edit_row?(ev, other, participant_id: "tok-alice")
  end
end

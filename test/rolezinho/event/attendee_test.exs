defmodule Rolezinho.Event.AttendeeTest do
  use ExUnit.Case, async: true

  alias Rolezinho.Event.Attendee

  describe "owned_by?/2" do
    test "matches the participant holding the same id" do
      attendee = %Attendee{participant_id: "abc123"}

      assert Attendee.owned_by?(attendee, "abc123")
    end

    test "rejects a different id" do
      attendee = %Attendee{participant_id: "abc123"}

      refute Attendee.owned_by?(attendee, "xyz789")
    end

    test "rejects an id of a different length without raising" do
      attendee = %Attendee{participant_id: "abc123"}

      refute Attendee.owned_by?(attendee, "short")
    end

    test "a row with no id is claimable by nobody" do
      refute Attendee.owned_by?(%Attendee{}, "abc123")
    end

    test "a browser sending nothing claims nothing" do
      attendee = %Attendee{participant_id: "abc123"}

      refute Attendee.owned_by?(attendee, nil)
      refute Attendee.owned_by?(attendee, "")
    end

    test "a blank stored id is not matched by a blank claim" do
      refute Attendee.owned_by?(%Attendee{participant_id: ""}, "")
    end
  end

  describe "changeset/2" do
    test "bounds the name, since writes to a list are anonymous" do
      changeset = Attendee.changeset(%Attendee{}, %{"name" => String.duplicate("a", 61)})

      refute changeset.valid?
      assert %{name: [_]} = Ecto.Changeset.traverse_errors(changeset, & &1)
    end

    test "accepts identity and custom answers" do
      changeset =
        Attendee.changeset(%Attendee{}, %{
          "name" => "Marcia",
          "participant_id" => "abc123",
          "values" => %{"shirt" => "M"}
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :participant_id) == "abc123"
      assert Ecto.Changeset.get_change(changeset, :values) == %{"shirt" => "M"}
    end
  end
end

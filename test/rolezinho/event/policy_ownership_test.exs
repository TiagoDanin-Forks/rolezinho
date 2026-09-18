defmodule Rolezinho.Event.PolicyOwnershipTest do
  @moduledoc """
  Focused tests on the "signed-in creator is organizer" branch added by
  ADR-0002. The rest of the policy matrix is exercised elsewhere; this
  file covers only the new source of `:organizer` and the ways it
  interacts with the existing ones.
  """
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Accounts
  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee
  alias Rolezinho.Event.Policy
  alias Rolezinho.Events

  defp new_user!(overrides \\ %{}) do
    {:ok, user} =
      Accounts.find_or_create_by_github(
        Map.merge(
          %{
            "github_id" => System.unique_integer([:positive]),
            "github_login" => "user-#{System.unique_integer([:positive])}"
          },
          overrides
        )
      )

    user
  end

  defp new_event!(created_by_user_id) do
    slug = "role-#{System.unique_integer([:positive])}"

    {:ok, event} =
      Events.create(
        %{
          "title" => "Rolê",
          "slug" => slug,
          "description" => "",
          "local" => "",
          "date" => "",
          "time" => "",
          "main_size" => "3",
          "wait_size" => "0",
          "password" => ""
        },
        admin?: true,
        created_by_user_id: created_by_user_id
      )

    event
  end

  describe "role/2 grants :organizer to the signed-in creator" do
    test "when current_user_id matches created_by_user_id" do
      user = new_user!()
      event = new_event!(user.id)

      assert Policy.role(event, current_user_id: user.id) == :organizer
    end

    test "even without holding the organizer_token or the admin bypass" do
      user = new_user!()
      event = new_event!(user.id)

      # No token, no admin — just the user id.
      assert Policy.role(event, current_user_id: user.id) == :organizer
    end
  end

  describe "role/2 does NOT grant :organizer" do
    test "to a different signed-in user" do
      creator = new_user!()
      someone_else = new_user!()

      event = new_event!(creator.id)

      assert Policy.role(event, current_user_id: someone_else.id) == :visitor
    end

    test "when the event has no creator (grandfathered pre-ADR-0002)" do
      user = new_user!()
      event = new_event!(nil)

      assert event.created_by_user_id == nil
      assert Policy.role(event, current_user_id: user.id) == :visitor
    end

    test "to a visitor with a stale/unknown user id" do
      creator = new_user!()
      event = new_event!(creator.id)

      assert Policy.role(event, current_user_id: -1) == :visitor
      assert Policy.role(event, current_user_id: nil) == :visitor
    end
  end

  describe "role/2 ordering" do
    test "admin still wins even when current_user_id also matches" do
      user = new_user!()
      event = new_event!(user.id)

      assert Policy.role(event, admin?: true, current_user_id: user.id) == :admin
    end

    test "explicit organizer? still wins over current_user_id (they should both grant it anyway)" do
      user = new_user!()
      event = new_event!(user.id)

      assert Policy.role(event, organizer?: true, current_user_id: user.id) == :organizer
    end

    test "creator role beats participant role" do
      user = new_user!()
      event = new_event!(user.id)

      # Put the same user's participant id on a row and see that the creator
      # role still wins — the more powerful role should be the one applied.
      {:ok, event} = Events.add_to_main(event, "Alice", participant_id: "some-participant")

      # This user did not join with `"some-participant"`, so they are not a
      # participant either — but even if they were, the ordering in role/2
      # promotes them to :organizer before :participant is even considered.
      assert Policy.role(event, current_user_id: user.id, participant_id: "some-participant") ==
               :organizer

      # And can_toggle_paid?/3 confirms it: an organizer can toggle any row.
      %{main_list: [%Attendee{} = row | _]} = event

      assert Policy.can_toggle_paid?(event, row,
               current_user_id: user.id,
               participant_id: "unrelated"
             )
    end
  end

  describe "Events.set_created_by/2 (admin move-owner)" do
    test "admin can move ownership to another user, granting them :organizer" do
      original = new_user!()
      new_owner = new_user!()
      event = new_event!(original.id)

      assert Policy.role(event, current_user_id: new_owner.id) == :visitor
      {:ok, moved} = Events.set_created_by(event, new_owner.id)
      assert moved.created_by_user_id == new_owner.id
      assert Policy.role(moved, current_user_id: new_owner.id) == :organizer
      assert Policy.role(moved, current_user_id: original.id) == :visitor
    end

    test "admin can clear ownership (back to grandfathered state)" do
      user = new_user!()
      event = new_event!(user.id)

      {:ok, cleared} = Events.set_created_by(event, nil)
      assert cleared.created_by_user_id == nil
      assert Policy.role(cleared, current_user_id: user.id) == :visitor
    end

    test "same-owner move is a no-op" do
      user = new_user!()
      event = new_event!(user.id)

      assert {:ok, ^event} = Events.set_created_by(event, user.id)
    end
  end

  describe "Event.changeset/2 does not accept created_by_user_id from params" do
    test "casting an event with :created_by_user_id in attrs ignores it" do
      changeset = Event.changeset(%Event{}, %{created_by_user_id: 999})
      # It's neither cast nor in changes.
      refute Ecto.Changeset.get_change(changeset, :created_by_user_id)
    end
  end
end

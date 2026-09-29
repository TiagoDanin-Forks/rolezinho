defmodule Rolezinho.EventsRecentNamesTest do
  @moduledoc """
  `Events.recent_names_for_user/2` — the autocomplete pool for the join
  form's name + guest inputs.

  Sources every attendee row (main OR wait) across every event whose
  `user_id` matches, canonicalizes, dedupes, orders most-recent-first,
  and truncates to `limit`.
  """
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Accounts
  alias Rolezinho.Events

  defp new_user!(login) do
    {:ok, user} =
      Accounts.find_or_create_by_github(%{
        "github_id" => System.unique_integer([:positive]),
        "github_login" => login
      })

    user
  end

  defp create_event(overrides \\ %{}) do
    defaults = %{
      "title" => "T",
      "slug" => "e-#{System.unique_integer([:positive])}",
      "main_size" => "9",
      "wait_size" => "3"
    }

    {:ok, event} = Events.create(Map.merge(defaults, overrides), admin?: true)
    event
  end

  test "returns [] for a nil user id (anonymous caller)" do
    assert Events.recent_names_for_user(nil) == []
  end

  test "returns [] for a user with no join history" do
    user = new_user!("ghost")
    assert Events.recent_names_for_user(user.id) == []
  end

  test "returns names from a party the user submitted, including guests" do
    user = new_user!("owner-1")
    event = create_event()

    {:ok, _updated, _} =
      Events.add_party(event, "Márcia", 3,
        participant_id: "tok",
        user_id: user.id,
        guest_names: ["Bruno", "Pedro"]
      )

    assert MapSet.new(Events.recent_names_for_user(user.id)) ==
             MapSet.new(["Márcia", "Bruno", "Pedro"])
  end

  test "dedupes canonically \u2014 mixed casings collapse to one entry" do
    user = new_user!("owner-2")
    e1 = create_event()

    {:ok, _, _} =
      Events.add_party(e1, "pedro Costa", 1,
        participant_id: "t1",
        user_id: user.id
      )

    e2 = create_event()

    {:ok, _, _} =
      Events.add_party(e2, "Pedro costa", 1,
        participant_id: "t2",
        user_id: user.id
      )

    e3 = create_event()

    {:ok, _, _} =
      Events.add_party(e3, "PEDRO COSTA", 1,
        participant_id: "t3",
        user_id: user.id
      )

    assert Events.recent_names_for_user(user.id) == ["Pedro Costa"]
  end

  test "ordered most-recent-first by joined_at" do
    user = new_user!("owner-3")

    e1 = create_event()

    {:ok, _, _} =
      Events.add_party(e1, "Ana", 1, participant_id: "a", user_id: user.id)

    Process.sleep(1_100)

    e2 = create_event()

    {:ok, _, _} =
      Events.add_party(e2, "Bruno", 1, participant_id: "b", user_id: user.id)

    Process.sleep(1_100)

    e3 = create_event()

    {:ok, _, _} =
      Events.add_party(e3, "Camila", 1, participant_id: "c", user_id: user.id)

    assert Events.recent_names_for_user(user.id) == ["Camila", "Bruno", "Ana"]
  end

  test "truncates to `limit`" do
    user = new_user!("owner-4")

    for i <- 1..30 do
      event = create_event()

      {:ok, _, _} =
        Events.add_party(event, "Pessoa #{i}", 1,
          participant_id: "p#{i}",
          user_id: user.id
        )
    end

    assert length(Events.recent_names_for_user(user.id, 25)) == 25
    assert length(Events.recent_names_for_user(user.id, 5)) == 5
  end

  test "does not leak names from OTHER users' joins" do
    mine = new_user!("mine")
    theirs = new_user!("theirs")

    e1 = create_event()

    {:ok, _, _} =
      Events.add_party(e1, "Mine Name", 1, participant_id: "m", user_id: mine.id)

    e2 = create_event()

    {:ok, _, _} =
      Events.add_party(e2, "Their Name", 1, participant_id: "t", user_id: theirs.id)

    assert Events.recent_names_for_user(mine.id) == ["Mine Name"]
    assert Events.recent_names_for_user(theirs.id) == ["Their Name"]
  end

  test "also picks up names from the wait list" do
    user = new_user!("waiter")
    event = create_event(%{"main_size" => "1", "wait_size" => "3"})

    # Fill the main slot with a stranger…
    {:ok, event} = Events.add_to_main(event, "Stranger", participant_id: "s")

    # …then the user joins with a party of two: main is full so both
    # of theirs land on the wait list.
    {:ok, _, %{main: 0, wait: 2}} =
      Events.add_party(event, "Waiter Name", 2,
        participant_id: "u",
        user_id: user.id,
        guest_names: ["Waiter Guest"]
      )

    assert MapSet.new(Events.recent_names_for_user(user.id)) ==
             MapSet.new(["Waiter Name", "Waiter Guest"])
  end
end

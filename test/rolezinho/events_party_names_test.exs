defmodule Rolezinho.EventsPartyNamesTest do
  @moduledoc """
  `add_party/4` with `:guest_names` — one name per guest position, with
  a "Convidado de X" fallback for blank/missing entries. The main person
  is unaffected; they always keep the name they submitted.
  """
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Events

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

  test "each guest gets their own row with the typed name" do
    event = create_event()

    {:ok, updated, %{main: 3}} =
      Events.add_party(event, "Márcia", 3,
        participant_id: "tok",
        guest_names: ["Bruno", "Pedro"]
      )

    names = updated.main_list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))
    assert names == ["Márcia", "Bruno", "Pedro"]
  end

  test "a blank guest name falls back to Convidado de X for that slot only" do
    event = create_event()

    {:ok, updated, _} =
      Events.add_party(event, "Márcia", 3,
        participant_id: "tok",
        guest_names: ["", "Pedro"]
      )

    names = updated.main_list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))
    assert names == ["Márcia", "Convidado de Márcia", "Pedro"]
  end

  test "no :guest_names opt falls back to the old \"Convidado de X\" for every guest" do
    event = create_event()

    {:ok, updated, _} =
      Events.add_party(event, "Márcia", 3, participant_id: "tok")

    names = updated.main_list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))
    assert names == ["Márcia", "Convidado de Márcia", "Convidado de Márcia"]
  end

  test "guest names are trimmed (via clean_name/1) just like the main name" do
    event = create_event()

    {:ok, updated, _} =
      Events.add_party(event, "Márcia", 2,
        participant_id: "tok",
        guest_names: ["  Bruno  "]
      )

    names = updated.main_list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))
    assert names == ["Márcia", "Bruno"]
  end

  test "more guest names than seats does not crash \u2014 extras are ignored" do
    event = create_event()

    {:ok, updated, %{main: 2}} =
      Events.add_party(event, "Márcia", 2,
        participant_id: "tok",
        guest_names: ["Bruno", "Pedro", "Ana"]
      )

    names = updated.main_list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))
    assert names == ["Márcia", "Bruno"]
  end
end

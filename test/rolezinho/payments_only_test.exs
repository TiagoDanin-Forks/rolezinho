defmodule Rolezinho.PaymentsOnlyTest do
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Event
  alias Rolezinho.Events

  defp create_event(attrs \\ %{}) do
    defaults = %{
      "title" => "T",
      "slug" => "po",
      "main_size" => "3",
      "wait_size" => "3"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  describe "set_status :payments_only" do
    setup do
      {:ok, event} = Events.set_status(create_event(), :payments_only)
      %{event: event}
    end

    test "list_open/0 includes payments_only events", %{event: event} do
      assert Enum.find(Events.list_open(), &(&1.id == event.id))
    end

    test "add_to_main is refused with :signups_locked", %{event: event} do
      assert {:error, :signups_locked} = Events.add_to_main(event, "Alice")
    end

    test "add_to_wait is refused with :signups_locked", %{event: event} do
      assert {:error, :signups_locked} = Events.add_to_wait(event, "Alice")
    end

    test "promote is refused with :signups_locked", %{event: event} do
      # Seed a wait entry via a temporary status swap
      {:ok, active} = Events.set_status(event, :active)
      {:ok, _} = Events.add_to_wait(active, "Someone")
      event = Events.find(event.slug)
      {:ok, event} = Events.set_status(event, :payments_only)

      assert {:error, :signups_locked} = Events.promote(event, 1)
    end
  end

  describe "to_text for payments_only" do
    test "omits vagas + entrar-na-espera lines" do
      event = %Event{
        status: :payments_only,
        title: "T",
        main_capacity: 3,
        main_list: [
          %Event.Attendee{name: "A", paid: true},
          %Event.Attendee{},
          %Event.Attendee{}
        ],
        wait_enabled: true,
        wait_intro: "Lista de reserva",
        wait_list: [%Event.Attendee{name: "W"}]
      }

      text = Event.to_text(event, "http://u/t")

      assert text =~ "1- A"
      # No vagas line
      refute text =~ ~r/\d+ vagas?:/
      # No entrar-na-espera line
      refute text =~ "Entrar na espera"
      # But the wait list content stays
      assert text =~ "1- W"
    end
  end
end

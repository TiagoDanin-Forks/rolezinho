defmodule Rolezinho.EventsTest do
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Event
  alias Rolezinho.Events
  alias Rolezinho.Repo

  describe "create/1" do
    test "creates an event and persists a file" do
      assert {:ok, %Event{} = event} =
               Events.create(%{
                 "title" => "Vôlei",
                 "slug" => "volei",
                 "description" => "End: Praia\nHorário: 19h",
                 "main_size" => "10",
                 "wait_size" => "3"
               })

      assert event.slug == "volei"
      assert event.main_capacity == 10
      assert length(event.main_list) == 10
      assert event.wait_enabled

      assert Repo.get_by(Event, slug: "volei").title == "Vôlei"
    end

    test "requires a valid slug" do
      assert {:error, %{slug: [_]}} =
               Events.create(%{
                 "title" => "T",
                 "slug" => "not valid!",
                 "main_size" => "5",
                 "wait_size" => "0"
               })
    end

    test "rejects duplicate slug" do
      {:ok, _} =
        Events.create(%{
          "title" => "A",
          "slug" => "dup",
          "main_size" => "5",
          "wait_size" => "0"
        })

      assert {:error, %{slug: [_]}} =
               Events.create(%{
                 "title" => "B",
                 "slug" => "dup",
                 "main_size" => "5",
                 "wait_size" => "0"
               })
    end

    test "0 in wait_size disables the wait list" do
      {:ok, event} =
        Events.create(%{
          "title" => "Sem reserva",
          "slug" => "sem-reserva",
          "main_size" => "3",
          "wait_size" => "0"
        })

      refute event.wait_enabled
    end
  end

  describe "list operations" do
    setup do
      {:ok, event} =
        Events.create(%{
          "title" => "T",
          "slug" => "t",
          "main_size" => "3",
          "wait_size" => "3"
        })

      %{event: event}
    end

    test "add_to_main persists a new attendee", %{event: event} do
      {:ok, updated} = Events.add_to_main(event, "Alice")
      reloaded = Events.find("t")
      assert Enum.at(updated.main_list, 0).name == "Alice"
      assert Enum.at(reloaded.main_list, 0).name == "Alice"
    end

    test "remove_main shifts everyone up", %{event: event} do
      {:ok, event} = Events.add_to_main(event, "A")
      {:ok, event} = Events.add_to_main(event, "B")
      {:ok, event} = Events.add_to_main(event, "C")
      {:ok, event} = Events.remove_main(event, 2)
      names = Enum.map(event.main_list, & &1.name)
      assert names == ["A", "C", ""]
    end

    test "promote from wait moves to main", %{event: event} do
      {:ok, event} = Events.add_to_wait(event, "Waiter")
      {:ok, event} = Events.promote(event, 1)
      assert Enum.at(event.main_list, 0).name == "Waiter"
      assert event.wait_list == []
    end

    test "toggle_paid_main flips the flag", %{event: event} do
      {:ok, event} = Events.add_to_main(event, "A")
      {:ok, event} = Events.toggle_paid_main(event, 1)
      assert Enum.at(event.main_list, 0).paid == true
    end
  end

  describe "rename_slug/2" do
    setup do
      {:ok, event} =
        Events.create(%{
          "title" => "T",
          "slug" => "antigo",
          "main_size" => "3",
          "wait_size" => "0"
        })

      %{event: event}
    end

    test "updates the row's slug", %{event: event} do
      assert {:ok, renamed} = Events.rename_slug(event, "novo")
      assert renamed.slug == "novo"

      assert Events.find("novo").title == "T"
      assert Events.find("antigo") == nil
    end

    test "is a no-op when the slug does not change", %{event: event} do
      assert {:ok, ^event} = Events.rename_slug(event, event.slug)
      assert Events.find(event.slug).id == event.id
    end

    test "normalizes the input (trims whitespace and lowercases)", %{event: event} do
      assert {:ok, renamed} = Events.rename_slug(event, "  NoVo  ")
      assert renamed.slug == "novo"
    end

    test "rejects malformed slugs", %{event: event} do
      assert {:error, :invalid_slug} = Events.rename_slug(event, "nao valido!")
      assert Events.find(event.slug).title == "T"
    end

    test "rejects a slug taken by another event", %{event: event} do
      {:ok, _other} =
        Events.create(%{
          "title" => "Outro",
          "slug" => "tomado",
          "main_size" => "1",
          "wait_size" => "0"
        })

      assert {:error, :slug_taken} = Events.rename_slug(event, "tomado")
    end

    test "keeps the current status when renaming", %{event: event} do
      {:ok, hidden} = Events.set_status(event, :hidden)
      assert {:ok, renamed} = Events.rename_slug(hidden, "escondido-novo")

      assert renamed.status == :hidden
      assert Events.find("escondido-novo").status == :hidden
      assert Events.find("antigo") == nil
    end
  end

  describe "clone/1" do
    setup do
      {:ok, event} =
        Events.create(%{
          "title" => "Vôlei",
          "slug" => "volei",
          "local" => "Praia",
          "date" => "2026-07-15",
          "time" => "19:00",
          "description" => "Valor: 15",
          "main_size" => "3",
          "wait_size" => "2"
        })

      {:ok, event} = Events.add_to_main(event, "Alice")
      {:ok, event} = Events.add_to_wait(event, "Bob")

      %{event: event}
    end

    test "appends ' Clonado' to the title and '-clonado' to the slug", %{event: event} do
      assert {:ok, clone} = Events.clone(event)
      assert clone.title == "Vôlei Clonado"
      assert clone.slug == "volei-clonado"
      assert clone.status == :active
    end

    test "copies the setup: header, capacity, footer", %{event: event} do
      assert {:ok, clone} = Events.clone(event)

      assert clone.header == event.header
      assert clone.main_capacity == event.main_capacity
      assert clone.wait_enabled == event.wait_enabled
    end

    test "starts with nobody on it (RN-52)", %{event: event} do
      # A repeat is next week's rolê. Carrying the list over would open it with
      # last week's names already confirmed, and their payment checks with them.
      assert {:ok, clone} = Events.clone(event)

      assert Enum.all?(clone.main_list, &(&1.name == ""))
      refute Enum.any?(clone.main_list, & &1.paid)
      assert clone.wait_list == []
    end

    test "keeps the same number of slots", %{event: event} do
      assert {:ok, clone} = Events.clone(event)

      assert length(clone.main_list) == event.main_capacity
    end

    test "gets its own organizer secret", %{event: event} do
      # Sharing one would let whoever organized the original administer the
      # repeat, and the other way round.
      assert {:ok, clone} = Events.clone(event)

      assert is_binary(clone.organizer_token)
      refute clone.organizer_token == event.organizer_token
    end

    test "cloning twice appends a numeric suffix to disambiguate the slug", %{event: event} do
      assert {:ok, first} = Events.clone(event)
      assert first.slug == "volei-clonado"

      assert {:ok, second} = Events.clone(event)
      assert second.slug == "volei-clonado-2"

      assert {:ok, third} = Events.clone(event)
      assert third.slug == "volei-clonado-3"
    end

    test "persists the clone in the database", %{event: event} do
      {:ok, clone} = Events.clone(event)
      assert Repo.get_by(Event, slug: clone.slug).title == "Vôlei Clonado"
    end
  end

  describe "status transitions" do
    setup do
      {:ok, event} =
        Events.create(%{
          "title" => "T",
          "slug" => "moveable",
          "main_size" => "1",
          "wait_size" => "0"
        })

      %{event: event}
    end

    test "set_status updates the row", %{event: event} do
      assert {:ok, hidden} = Events.set_status(event, :hidden)
      assert hidden.status == :hidden
      assert Repo.get_by(Event, slug: "moveable").status == :hidden

      # hidden events don't show on home
      assert Events.list_active() == []
      # but findable
      assert Events.find("moveable").status == :hidden
    end

    test "done events aren't public", %{event: event} do
      {:ok, done} = Events.set_status(event, :done)
      assert done.status == :done
      refute Events.find("moveable", visibility: :public)
      assert Events.find("moveable", visibility: :any).status == :done
    end
  end
end

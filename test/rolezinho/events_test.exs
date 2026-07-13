defmodule Rolezinho.EventsTest do
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Event
  alias Rolezinho.Events

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

      assert File.exists?(Events.file_path("volei", :active))
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

    test "set_status moves the file", %{event: event} do
      assert {:ok, hidden} = Events.set_status(event, :hidden)
      assert hidden.status == :hidden
      refute File.exists?(Events.file_path("moveable", :active))
      assert File.exists?(Events.file_path("moveable", :hidden))

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

defmodule Rolezinho.PasswordTest do
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Event
  alias Rolezinho.Events

  defp create_event(attrs \\ %{}) do
    defaults = %{
      "title" => "T",
      "slug" => "pw",
      "main_size" => "3",
      "wait_size" => "0"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  describe "create with password" do
    test "stores the password verbatim when provided" do
      event = create_event(%{"slug" => "com-senha", "password" => "senhinha"})
      assert event.password == "senhinha"
      assert Event.password_protected?(event)
    end

    test "treats empty/whitespace passwords as nil" do
      event = create_event(%{"slug" => "sem-senha", "password" => "   "})
      assert event.password == nil
      refute Event.password_protected?(event)
    end
  end

  describe "update_password/2" do
    setup do
      %{event: create_event()}
    end

    test "sets a password", %{event: event} do
      assert {:ok, updated} = Events.update_password(event, "abc123")
      assert updated.password == "abc123"
    end

    test "changes the password", %{event: event} do
      {:ok, event} = Events.update_password(event, "old")
      {:ok, event} = Events.update_password(event, "new")
      assert event.password == "new"
    end

    test "clears the password when empty", %{event: event} do
      {:ok, event} = Events.update_password(event, "will-clear")
      assert {:ok, cleared} = Events.update_password(event, "")
      assert cleared.password == nil
    end
  end

  describe "check_password/2" do
    test "always true when the event has no password" do
      event = %Event{password: nil}
      assert Events.check_password(event, "anything")
      assert Events.check_password(event, "")
    end

    test "matches only the exact password" do
      event = %Event{password: "abc123"}
      assert Events.check_password(event, "abc123")
      refute Events.check_password(event, "abc")
      refute Events.check_password(event, "ABC123")
    end
  end

  describe "clone copies the password" do
    test "clone/1 keeps the source password on the clone" do
      event = create_event(%{"slug" => "cloneme", "password" => "s3cret"})
      assert {:ok, clone} = Events.clone(event)
      assert clone.password == "s3cret"
    end
  end

  describe "to_text with strip_location" do
    test "removes the `Local:` line when asked" do
      event = %Event{
        title: "T",
        header: "Local: Praia\nData: 15/07/2026\nValor: 15",
        main_capacity: 1,
        main_list: [%Event.Attendee{name: "A"}],
        wait_enabled: false
      }

      full = Event.to_text(event, "http://u/t")
      assert full =~ "Local: Praia"

      stripped = Event.to_text(event, "http://u/t", strip_location: true)
      refute stripped =~ "Local: Praia"
      # But the other meta lines and free-form content stick around
      assert stripped =~ "Data: 15/07/2026"
      assert stripped =~ "Valor: 15"
    end
  end
end

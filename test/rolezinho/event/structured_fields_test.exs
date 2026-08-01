defmodule Rolezinho.Event.StructuredFieldsTest do
  use Rolezinho.DataCase, async: true

  alias Rolezinho.Event
  alias Rolezinho.Events

  defp create_event(attrs \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei-#{System.unique_integer([:positive])}",
      "description" => "End: Praia",
      "main_size" => "3",
      "wait_size" => "0"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  describe "organizer token" do
    test "is issued when the event is created" do
      event = create_event()

      assert is_binary(event.organizer_token)
      assert event.organizer_token != ""
    end

    test "differs between events, so a token administers exactly one" do
      first = create_event()
      second = create_event()

      refute first.organizer_token == second.organizer_token
    end

    test "cannot be chosen through params" do
      changeset = Event.changeset(%Event{}, %{"organizer_token" => "chosen-by-the-visitor"})

      refute Ecto.Changeset.get_change(changeset, :organizer_token)
    end

    test "resolves the event it administers" do
      event = create_event()

      assert %Event{id: id} = Events.get_by_organizer_token(event.organizer_token)
      assert id == event.id
    end

    test "a browser sending no token resolves to no event" do
      create_event()

      assert Events.get_by_organizer_token(nil) == nil
      assert Events.get_by_organizer_token("") == nil
      assert Events.get_by_organizer_token("not-a-real-token") == nil
    end
  end

  describe "structured fields" do
    test "persist alongside the event" do
      starts_at = ~U[2026-07-15 22:00:00Z]
      ends_at = ~U[2026-07-16 00:00:00Z]

      changeset =
        Event.changeset(%Event{}, %{
          "slug" => "structured",
          "title" => "Vôlei",
          "status" => :active,
          "category" => "sport",
          "local" => "Rua Caripunas",
          "starts_at" => starts_at,
          "ends_at" => ends_at,
          "price_cents" => 1500,
          "pix_key" => "91984933238"
        })

      assert {:ok, event} = Repo.insert(changeset)
      assert event.local == "Rua Caripunas"
      assert event.price_cents == 1500
      assert event.pix_key == "91984933238"
      assert DateTime.compare(event.starts_at, starts_at) == :eq
    end

    test "an event cannot end before it starts" do
      changeset =
        Event.changeset(%Event{}, %{
          "slug" => "backwards",
          "title" => "Vôlei",
          "status" => :active,
          "starts_at" => ~U[2026-07-15 22:00:00Z],
          "ends_at" => ~U[2026-07-15 20:00:00Z]
        })

      refute changeset.valid?
      assert %{ends_at: ["precisa ser depois do início"]} = errors_on(changeset)
    end

    test "an event with no end time is fine" do
      changeset =
        Event.changeset(%Event{}, %{
          "slug" => "open-ended",
          "title" => "Vôlei",
          "status" => :active,
          "starts_at" => ~U[2026-07-15 22:00:00Z]
        })

      assert changeset.valid?
    end

    test "a negative price is rejected" do
      changeset =
        Event.changeset(%Event{}, %{
          "slug" => "negative",
          "title" => "Vôlei",
          "status" => :active,
          "price_cents" => -100
        })

      refute changeset.valid?
      assert %{price_cents: [_]} = errors_on(changeset)
    end

    test "free text stays bounded, since anyone can write to an event" do
      changeset =
        Event.changeset(%Event{}, %{
          "slug" => "long",
          "title" => "Vôlei",
          "status" => :active,
          "local" => String.duplicate("a", 201)
        })

      refute changeset.valid?
      assert %{local: [_]} = errors_on(changeset)
    end
  end
end

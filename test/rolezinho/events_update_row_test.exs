defmodule Rolezinho.EventsUpdateRowTest do
  @moduledoc """
  `Rolezinho.Events.update_main/3` and `update_wait/3` — the persistence
  path used by the row-owner edit flow on `/r/:slug`.

  What we lock down here:

    * name updates persist and are cleaned like the join path,
    * form-field values persist and only the fields the event asks for
      pass through,
    * unknown keys are dropped (a hostile browser cannot invent columns),
    * blank/whitespace values drop the entry rather than store empty,
    * long values are capped at 200 chars (same rule as joining),
    * a blank name is a no-op on that field (never blanks the row).
  """
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Events

  defp create_event(attrs \\ %{}) do
    defaults = %{
      "title" => "Voléi",
      "slug" => "volei-#{System.unique_integer([:positive])}",
      "description" => "",
      "local" => "",
      "date" => "",
      "time" => "",
      "main_size" => "3",
      "wait_size" => "2",
      "password" => ""
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs), admin?: true)
    event
  end

  defp seed_with_row(overrides \\ %{}) do
    event = create_event()
    {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa"})

    {:ok, event, _placed} =
      Events.add_party(event, "Márcia", 1,
        participant_id: "tok-marcia",
        values: Map.merge(%{"camisa" => "M"}, overrides)
      )

    event
  end

  describe "update_main/3" do
    test "updates the name in place" do
      event = seed_with_row()

      assert {:ok, updated} =
               Events.update_main(event, 1, %{"name" => "  Marcia F.  "})

      row = List.first(updated.main_list)
      assert row.name == "Marcia F."
      # Values untouched when the caller only sends a name.
      assert row.values == %{"camisa" => "M"}
    end

    test "updates the values in place" do
      event = seed_with_row()

      assert {:ok, updated} =
               Events.update_main(event, 1, %{"values" => %{"camisa" => "G"}})

      row = List.first(updated.main_list)
      assert row.name == "Márcia"
      assert row.values == %{"camisa" => "G"}
    end

    test "updates name and values in one shot" do
      event = seed_with_row()

      assert {:ok, updated} =
               Events.update_main(event, 1, %{
                 "name" => "Marcia",
                 "values" => %{"camisa" => "P"}
               })

      row = List.first(updated.main_list)
      assert row.name == "Marcia"
      assert row.values == %{"camisa" => "P"}
    end

    test "drops unknown keys from the values map" do
      event = seed_with_row()

      assert {:ok, updated} =
               Events.update_main(event, 1, %{
                 "values" => %{"camisa" => "GG", "cpf" => "123.456.789-00"}
               })

      row = List.first(updated.main_list)
      assert row.values == %{"camisa" => "GG"}
      refute Map.has_key?(row.values, "cpf")
    end

    test "blank/whitespace value drops the entry rather than storing an empty string" do
      event = seed_with_row()

      assert {:ok, updated} =
               Events.update_main(event, 1, %{"values" => %{"camisa" => "   "}})

      row = List.first(updated.main_list)
      assert row.values == %{}
    end

    test "caps a very long value at 200 chars" do
      event = seed_with_row()
      long = String.duplicate("a", 500)

      assert {:ok, updated} =
               Events.update_main(event, 1, %{"values" => %{"camisa" => long}})

      row = List.first(updated.main_list)
      assert String.length(row.values["camisa"]) == 200
    end

    test "a blank name is a no-op on that field (never blanks the row)" do
      event = seed_with_row()

      assert {:ok, updated} =
               Events.update_main(event, 1, %{
                 "name" => "   ",
                 "values" => %{"camisa" => "P"}
               })

      row = List.first(updated.main_list)
      assert row.name == "Márcia"
      assert row.values == %{"camisa" => "P"}
    end
  end

  describe "update_wait/3" do
    test "updates a wait-list row's name and values" do
      event = create_event()
      {:ok, event} = Events.add_form_field(event, %{"label" => "Camisa"})

      {:ok, event} = Events.add_to_wait(event, "Ana", values: %{"camisa" => "M"})

      assert {:ok, updated} =
               Events.update_wait(event, 1, %{
                 "name" => "Ana Paula",
                 "values" => %{"camisa" => "G"}
               })

      row = List.first(updated.wait_list)
      assert row.name == "Ana Paula"
      assert row.values == %{"camisa" => "G"}
    end
  end
end

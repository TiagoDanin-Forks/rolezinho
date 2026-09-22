defmodule Rolezinho.EventsHiddenFlagTest do
  @moduledoc """
  The `hidden` boolean is a separate axis from `:status` after the
  2026-09 split. This exercises the two things that used to be one:

    * an event can be `hidden: true` while `status: :payments_only`
      (impossible under the old encoding where `:hidden` was a status),
    * `list_open/0` filters on BOTH axes (open status AND not hidden),
    * `list_hidden/0` returns rows keyed off the boolean, regardless
      of status.
  """
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Events

  defp create_event(attrs \\ %{}) do
    defaults = %{
      "title" => "T",
      "slug" => "e-#{System.unique_integer([:positive])}",
      "main_size" => "3",
      "wait_size" => "0"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs), admin?: true)
    event
  end

  describe "set_hidden/2" do
    test "flips the flag and persists it" do
      event = create_event()
      refute event.hidden

      assert {:ok, hidden} = Events.set_hidden(event, true)
      assert hidden.hidden == true
      assert Events.find(hidden.slug).hidden == true

      assert {:ok, back} = Events.set_hidden(hidden, false)
      assert back.hidden == false
    end

    test "is a no-op when the flag is already at the requested value" do
      event = create_event()
      assert {:ok, same} = Events.set_hidden(event, false)
      assert same.updated_at == event.updated_at
    end

    test "leaves status untouched" do
      event = create_event()
      {:ok, event} = Events.set_status(event, :payments_only)

      assert {:ok, hidden} = Events.set_hidden(event, true)
      assert hidden.status == :payments_only
      assert hidden.hidden == true
    end
  end

  describe "orthogonality" do
    test "an event can be payments_only AND hidden at the same time" do
      # This combination was unrepresentable under the old encoding, where
      # `:hidden` was a status value.
      event = create_event(%{"slug" => "orth-1"})
      {:ok, event} = Events.set_status(event, :payments_only)
      {:ok, event} = Events.set_hidden(event, true)

      reloaded = Events.find("orth-1")
      assert reloaded.status == :payments_only
      assert reloaded.hidden == true
    end
  end

  describe "list_open/0 and list_hidden/0 filters" do
    test "list_open excludes hidden events regardless of status" do
      visible = create_event(%{"slug" => "vis-1"})
      hidden = create_event(%{"slug" => "hid-1"})
      {:ok, _} = Events.set_hidden(hidden, true)

      slugs = Events.list_open() |> Enum.map(& &1.slug)
      assert visible.slug in slugs
      refute hidden.slug in slugs
    end

    test "list_hidden returns hidden events across statuses" do
      a = create_event(%{"slug" => "hid-a"})
      b = create_event(%{"slug" => "hid-b"})
      c = create_event(%{"slug" => "vis-c"})

      {:ok, _} = Events.set_hidden(a, true)
      {:ok, b_hidden} = Events.set_hidden(b, true)
      {:ok, _} = Events.set_status(b_hidden, :payments_only)

      slugs = Events.list_hidden() |> Enum.map(& &1.slug)
      assert "hid-a" in slugs
      assert "hid-b" in slugs
      refute "vis-c" in slugs
    end
  end
end

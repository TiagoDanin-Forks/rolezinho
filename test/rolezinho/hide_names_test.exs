defmodule Rolezinho.HideNamesTest do
  use ExUnit.Case, async: true

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee

  defp event_with_lists do
    %Event{
      title: "T",
      main_capacity: 3,
      main_list: [
        %Attendee{name: "Alice", paid: true},
        %Attendee{name: "Bob", paid: false},
        %Attendee{}
      ],
      wait_enabled: true,
      wait_intro: "Lista de reserva",
      wait_list: [
        %Attendee{name: "Wanda", paid: false}
      ]
    }
  end

  test "hide_names replaces filled attendee names with the placeholder" do
    text = Event.to_text(event_with_lists(), "http://roles/t", hide_names: true)

    placeholder = Event.hidden_name_placeholder()

    assert text =~ "1- #{placeholder} ✅"
    assert text =~ "2- #{placeholder}"
    refute text =~ "Alice"
    refute text =~ "Bob"
    refute text =~ "Wanda"
    # Wait list is also masked
    assert text =~ "1- #{placeholder}"
  end

  test "hide_names preserves the empty-slot line as empty (no placeholder)" do
    text = Event.to_text(event_with_lists(), "http://roles/t", hide_names: true)
    # We do not want "3- •••" for the empty slot — empty slots remain empty.
    refute text =~ "3- •••"
    assert text =~ "1 vaga: http://roles/t"
  end

  test "hide_names has no effect when combined with normal (unlocked) rendering" do
    without = Event.to_text(event_with_lists(), "http://roles/t")
    assert without =~ "Alice"
    assert without =~ "Wanda"
    refute without =~ Event.hidden_name_placeholder()
  end

  test "hide_names is default-false" do
    text = Event.to_text(event_with_lists(), "http://roles/t")
    assert text =~ "Alice"
  end

  test "paid checkmark is preserved even when the name is hidden" do
    text = Event.to_text(event_with_lists(), "http://roles/t", hide_names: true)
    assert text =~ "1- #{Event.hidden_name_placeholder()} ✅"
  end

  test "render/1 (persisted form) is unaffected by hide_names semantics" do
    # The `render/1` output is what would go into the raw editor — always
    # shows real names since only admins ever see it.
    rendered = Event.render(event_with_lists())
    assert rendered =~ "1- Alice"
    assert rendered =~ "2- Bob"
    refute rendered =~ Event.hidden_name_placeholder()
  end
end

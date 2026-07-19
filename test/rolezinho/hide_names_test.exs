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

  describe "hide_description" do
    test "omits the entire header (meta lines + free-form)" do
      event = %Event{
        title: "T",
        header:
          "Local: Rua X\nData: 15/07/2026\nHorário: 19:00 (BRT)\n\nValor: 15\nPix: 91984933238",
        main_capacity: 1,
        main_list: [%Attendee{name: "A"}],
        wait_enabled: false
      }

      text = Event.to_text(event, "http://roles/t", hide_description: true)

      refute text =~ "Local: Rua X"
      refute text =~ "Data: 15/07/2026"
      refute text =~ "Horário: 19:00"
      refute text =~ "Valor: 15"
      refute text =~ "Pix:"
      # But title, URL and list stay visible
      assert text =~ "http://roles/t"
      assert text =~ "T"
      assert text =~ "1- A"
    end

    test "takes precedence over strip_location" do
      event = %Event{
        title: "T",
        header: "Local: Rua X\nValor: 15",
        main_capacity: 1,
        main_list: [%Attendee{name: "A"}],
        wait_enabled: false
      }

      text =
        Event.to_text(event, "http://roles/t",
          strip_location: true,
          hide_description: true
        )

      refute text =~ "Rua X"
      refute text =~ "Valor:"
    end

    test "is a no-op when off" do
      event = %Event{
        title: "T",
        header: "Valor: 15",
        main_capacity: 1,
        main_list: [%Attendee{name: "A"}],
        wait_enabled: false
      }

      text = Event.to_text(event, "http://roles/t")
      assert text =~ "Valor: 15"
    end
  end
end

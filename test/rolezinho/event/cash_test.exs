defmodule Rolezinho.Event.CashTest do
  use ExUnit.Case, async: true

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee
  alias Rolezinho.Event.Cash

  defp event(attrs) do
    defaults = %{
      slug: "volei",
      title: "Vôlei",
      status: :active,
      price_cents: 1500,
      pix_key: "91984933238",
      main_capacity: 4,
      main_list: [],
      wait_list: []
    }

    struct(Event, Map.merge(defaults, attrs))
  end

  defp person(name, paid), do: %Attendee{name: name, paid: paid}
  defp empty, do: %Attendee{name: "", paid: false}

  describe "summary/1" do
    test "counts what is expected against what has been declared" do
      event =
        event(%{
          main_list: [person("Marcia", true), person("Roberta", false), person("Ana", true)]
        })

      summary = Cash.summary(event)

      assert summary.expected_cents == 4500
      assert summary.received_cents == 3000
      assert summary.missing_cents == 1500
      assert summary.debtors == ["Roberta"]
    end

    test "an empty slot owes nothing" do
      event = event(%{main_list: [person("Marcia", true), empty(), empty()]})

      summary = Cash.summary(event)

      assert summary.expected_cents == 1500
      assert summary.total_count == 1
      assert summary.debtors == []
    end

    test "the waiting list is not charged, having no place yet" do
      event =
        event(%{
          main_list: [person("Marcia", true)],
          wait_list: [person("Rivanete", false)]
        })

      summary = Cash.summary(event)

      assert summary.expected_cents == 1500
      assert summary.debtors == []
    end

    test "a free event expects nothing" do
      event = event(%{price_cents: nil, main_list: [person("Marcia", false)]})

      summary = Cash.summary(event)

      assert summary.expected_cents == 0
      assert summary.missing_cents == 0
    end
  end

  describe "outstanding?/1" do
    test "is true while somebody has not declared payment" do
      event = event(%{main_list: [person("Marcia", true), person("Roberta", false)]})

      assert Cash.outstanding?(event)
    end

    test "is false once everybody has" do
      event = event(%{main_list: [person("Marcia", true), person("Roberta", true)]})

      refute Cash.outstanding?(event)
    end

    test "is false for a free event, where there is nothing to chase" do
      event = event(%{price_cents: nil, main_list: [person("Marcia", false)]})

      refute Cash.outstanding?(event)
    end
  end

  describe "reminder_text/1" do
    test "names everyone who owes in a single message" do
      event =
        event(%{
          main_list: [person("Marcia", true), person("Roberta", false), person("Henrique", false)]
        })

      text = Cash.reminder_text(event)

      assert text =~ "Roberta, Henrique"
      refute text =~ "Marcia"
      assert text =~ "R$ 15 cada"
      assert text =~ "Pix 91984933238"
    end

    test "is nil when nobody owes, so callers need no empty case" do
      event = event(%{main_list: [person("Marcia", true)]})

      assert Cash.reminder_text(event) == nil
    end

    test "drops the amount line for a free event" do
      event = event(%{price_cents: nil, pix_key: nil, main_list: [person("Marcia", false)]})

      text = Cash.reminder_text(event)

      assert text =~ "Marcia"
      refute text =~ "R$"
      # The word "Pix" still appears in "faltou o Pix de"; what must be absent is
      # a key line for an event that has no key.
      refute text =~ "Pix 9"
      assert text == "Vôlei · faltou o Pix de: Marcia"
    end
  end

  describe "format_amount/1" do
    test "writes whole amounts the way people say them" do
      assert Cash.format_amount(1500) == "R$ 15"
      assert Cash.format_amount(5000) == "R$ 50"
    end

    test "keeps the cents when there are any" do
      assert Cash.format_amount(1550) == "R$ 15,50"
      assert Cash.format_amount(1505) == "R$ 15,05"
    end

    test "a free event has no amount to show" do
      assert Cash.format_amount(nil) == nil
      assert Cash.format_amount(0) == nil
    end
  end
end

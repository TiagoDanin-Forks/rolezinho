defmodule Rolezinho.Events.ChatUpdateTest do
  @moduledoc """
  Unit coverage for the URL-scheme parser that turns LLM-generated
  query strings into `%ChatUpdate{}` proposals. Locks in:

    * `names[i]` → indexed row names, absent means "leave alone",
      explicit empty means "clear".
    * `fields[i][key]` → per-row custom-field values, keys
      normalized the same way form-field ids are built.
    * `checks[i]` → paid tri-state (truthy / falsy / unspecified),
      including Portuguese synonyms (`sim`, `não`).
    * `wait_names[i]` / `wait_checks[i]` populate the wait rows.
    * `event=<slug>` becomes `event_slug`.
    * `field_keys` collect **unique** keys in first-appearance order.
    * Malformed entries (non-numeric indices, non-map fields, unknown
      truthiness values) are silently dropped.
  """
  use ExUnit.Case, async: true

  alias Rolezinho.Events.ChatUpdate
  alias Rolezinho.Events.ChatUpdate.Row

  describe "parse/1 — names & event" do
    test "picks up the event slug" do
      assert %ChatUpdate{event_slug: "volei-30-09"} =
               ChatUpdate.parse(%{"event" => "volei-30-09"})
    end

    test "blank event collapses to nil" do
      assert %ChatUpdate{event_slug: nil} = ChatUpdate.parse(%{"event" => "  "})
    end

    test "translates names[i]=Foo into indexed Row{name: 'Foo'}" do
      params = %{"names" => %{"0" => "Alice", "1" => "Bruno"}}

      assert %ChatUpdate{main_rows: rows} = ChatUpdate.parse(params)

      assert [
               %Row{index: 0, name: "Alice", values: nil, paid: nil},
               %Row{index: 1, name: "Bruno", values: nil, paid: nil}
             ] = rows
    end

    test "an explicit empty names[i]= becomes an empty-string Row (a clear)" do
      assert %ChatUpdate{main_rows: [%Row{index: 3, name: ""}]} =
               ChatUpdate.parse(%{"names" => %{"3" => ""}})
    end

    test "rows are sorted by index no matter the input order" do
      params = %{"names" => %{"2" => "C", "0" => "A", "5" => "F"}}

      assert %ChatUpdate{main_rows: rows} = ChatUpdate.parse(params)
      assert Enum.map(rows, & &1.index) == [0, 2, 5]
    end

    test "non-numeric indices are silently dropped" do
      params = %{"names" => %{"abc" => "Zé", "0" => "Alice"}}
      assert %ChatUpdate{main_rows: [%Row{index: 0, name: "Alice"}]} = ChatUpdate.parse(params)
    end
  end

  describe "parse/1 — fields" do
    test "translates fields[0][shirt]=M into Row.values" do
      params = %{"fields" => %{"0" => %{"shirt" => "M"}}}

      assert %ChatUpdate{main_rows: [row]} = ChatUpdate.parse(params)
      assert row.values == %{"shirt" => "M"}
    end

    test "normalizes keys the same way form-field ids are built" do
      params = %{"fields" => %{"0" => %{"Nome na Camisa" => "Alice A."}}}

      assert %ChatUpdate{main_rows: [row], field_keys: keys} = ChatUpdate.parse(params)
      assert row.values == %{"nome-na-camisa" => "Alice A."}
      assert keys == ["nome-na-camisa"]
    end

    test "accented keys collapse consistently" do
      params = %{"fields" => %{"0" => %{"Camisa (P/M/G)" => "M"}}}
      assert %ChatUpdate{main_rows: [row]} = ChatUpdate.parse(params)
      assert row.values == %{"camisa-p-m-g" => "M"}
    end

    test "non-map fields[i] value is silently dropped" do
      params = %{"fields" => %{"0" => "not a map"}}
      assert %ChatUpdate{main_rows: [], field_keys: []} = ChatUpdate.parse(params)
    end

    test "field_keys are unique and grouped by row appearance" do
      params = %{
        "fields" => %{
          "0" => %{"shirt" => "M", "number" => "10"},
          "1" => %{"number" => "7", "shirt" => "G"},
          "2" => %{"color" => "black"}
        }
      }

      assert %ChatUpdate{field_keys: keys} = ChatUpdate.parse(params)

      # Uniqueness is the invariant — no key listed twice, and every
      # key that appears in any row is collected. Within-row key
      # order matches Map iteration (Elixir maps aren't insertion-
      # ordered), so we assert on membership + total, not sequence.
      assert Enum.sort(keys) == ["color", "number", "shirt"]
      assert length(keys) == 3

      # `color` only appears in row 2, so it must be listed after
      # both `shirt` and `number` regardless of within-row order.
      color_idx = Enum.find_index(keys, &(&1 == "color"))
      shirt_idx = Enum.find_index(keys, &(&1 == "shirt"))
      number_idx = Enum.find_index(keys, &(&1 == "number"))
      assert color_idx > shirt_idx
      assert color_idx > number_idx
    end
  end

  describe "parse/1 — checks (paid)" do
    test "truthy values → true, falsy → false, unknown → nil" do
      params = %{
        "checks" => %{
          "0" => "1",
          "1" => "true",
          "2" => "sim",
          "3" => "0",
          "4" => "não",
          "5" => "wat"
        },
        "names" => %{
          "0" => "A",
          "1" => "B",
          "2" => "C",
          "3" => "D",
          "4" => "E",
          "5" => "F"
        }
      }

      assert %ChatUpdate{main_rows: rows} = ChatUpdate.parse(params)

      paid_by_index = Map.new(rows, fn r -> {r.index, r.paid} end)

      assert paid_by_index == %{
               0 => true,
               1 => true,
               2 => true,
               3 => false,
               4 => false,
               5 => nil
             }
    end

    test "absent check leaves paid at nil" do
      assert %ChatUpdate{main_rows: [%Row{index: 0, paid: nil}]} =
               ChatUpdate.parse(%{"names" => %{"0" => "Alice"}})
    end
  end

  describe "parse/1 — wait list" do
    test "wait_names + wait_checks populate wait_rows" do
      params = %{
        "wait_names" => %{"0" => "X", "1" => "Y"},
        "wait_checks" => %{"1" => "1"}
      }

      assert %ChatUpdate{wait_rows: rows} = ChatUpdate.parse(params)

      assert [
               %Row{index: 0, name: "X", paid: nil},
               %Row{index: 1, name: "Y", paid: true}
             ] = rows
    end

    test "wait_fields populate the wait row's values map" do
      params = %{
        "wait_names" => %{"0" => "X"},
        "wait_fields" => %{"0" => %{"tamanho" => "P"}}
      }

      assert %ChatUpdate{wait_rows: [row], field_keys: keys} = ChatUpdate.parse(params)
      assert row.values == %{"tamanho" => "P"}
      # Field keys from wait rows are collected too — the event-wide
      # form_field set applies to both lists, so a wait-only key
      # still needs to show up as a "new field" chip.
      assert "tamanho" in keys
    end
  end

  describe "parse/1 — field_labels" do
    test "picks up the LLM-supplied human label for a slug key" do
      params = %{
        "fields" => %{"0" => %{"nome-na-camisa" => "Alice A."}},
        "field_labels" => %{"nome-na-camisa" => "Nome na camisa"}
      }

      assert %ChatUpdate{field_labels: labels} = ChatUpdate.parse(params)
      assert labels == %{"nome-na-camisa" => "Nome na camisa"}
    end

    test "normalizes the label's key so it always matches the fields key" do
      params = %{
        "fields" => %{"0" => %{"tamanho" => "M"}},
        # LLM sent the key with different casing/spacing.
        "field_labels" => %{"Tamanho" => "Tamanho"}
      }

      assert %ChatUpdate{field_labels: labels} = ChatUpdate.parse(params)
      assert Map.has_key?(labels, "tamanho")
    end

    test "absent / empty / non-string labels are dropped" do
      params = %{
        "field_labels" => %{
          "a" => "  ",
          "b" => "",
          "c" => nil,
          "d" => "Real Label"
        }
      }

      assert %ChatUpdate{field_labels: labels} = ChatUpdate.parse(params)
      assert labels == %{"d" => "Real Label"}
    end
  end

  describe "parse/1 — capacity" do
    test "positive integer becomes main_capacity" do
      assert %ChatUpdate{main_capacity: 25} = ChatUpdate.parse(%{"capacity" => "25"})
    end

    test "already-integer values also work" do
      assert %ChatUpdate{main_capacity: 12} = ChatUpdate.parse(%{"capacity" => 12})
    end

    test "zero / negative / garbage collapse to nil" do
      assert %ChatUpdate{main_capacity: nil} = ChatUpdate.parse(%{"capacity" => "0"})
      assert %ChatUpdate{main_capacity: nil} = ChatUpdate.parse(%{"capacity" => "-5"})
      assert %ChatUpdate{main_capacity: nil} = ChatUpdate.parse(%{"capacity" => "lots"})
      assert %ChatUpdate{main_capacity: nil} = ChatUpdate.parse(%{"capacity" => ""})
    end

    test "absent capacity is nil (LiveView falls back to event's current)" do
      assert %ChatUpdate{main_capacity: nil} = ChatUpdate.parse(%{})
    end
  end

  describe "parse/1 — resilience" do
    test "returns empty ChatUpdate for a non-map input" do
      assert %ChatUpdate{main_rows: [], wait_rows: [], event_slug: nil} =
               ChatUpdate.parse("not a map")
    end

    test "returns empty ChatUpdate for an empty map" do
      assert %ChatUpdate{main_rows: [], wait_rows: [], event_slug: nil} =
               ChatUpdate.parse(%{})
    end
  end

  describe "normalize_field_key/1" do
    test "matches Event.FormField.build_id/2 output byte-for-byte" do
      # If either normalizer drifts, the reconciliation in the
      # LiveView silently starts misclassifying keys. Guard both
      # from the same test.
      labels = [
        "Tamanho",
        "Nome na camisa",
        "Camisa (P/M/G)",
        "Número",
        "ÁGUA / SUCO"
      ]

      for label <- labels do
        expected = Rolezinho.Event.FormField.build_id(label, [])
        assert ChatUpdate.normalize_field_key(label) == expected
      end
    end
  end
end

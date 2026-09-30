defmodule Rolezinho.Events.ChatUpdateTest do
  @moduledoc """
  Unit coverage for the URL-scheme parser that turns LLM-generated
  query strings into `%ChatUpdate{}` proposals. Locks in:
  What we lock in:

    * `names[i]` → indexed row names, absent means "leave alone",
      explicit empty means "clear".
    * `fields[i][key]` → per-row custom-field values, keys
      normalized the same way form-field ids are built.
    * `checks[i]` → paid tri-state (truthy / falsy / unspecified),
      including Portuguese synonyms (`sim`, `não`).
    * `wait_names[i]` / `wait_checks[i]` populate the wait rows.
    * `field_keys` collect **unique** keys in first-appearance order.
    * Malformed entries (non-numeric indices, non-map fields, unknown
      truthiness values) are silently dropped.

  The parser does NOT read any `event` slug from the URL — event
  selection lives at the routing layer (`/atualizar/:slug`), never in
  the query string. This keeps the LLM's URL contract event-agnostic.
  """
  use ExUnit.Case, async: true

  alias Rolezinho.Events.ChatUpdate
  alias Rolezinho.Events.ChatUpdate.Row

  describe "parse/1 — names" do
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
      assert %ChatUpdate{main_rows: [], wait_rows: []} = ChatUpdate.parse("not a map")
    end

    test "returns empty ChatUpdate for an empty map" do
      assert %ChatUpdate{main_rows: [], wait_rows: []} = ChatUpdate.parse(%{})
    end

    test "an `event` param is silently ignored (parser is event-agnostic)" do
      # Regression: the URL scheme moved event selection out of the
      # query string in 2026-09; a stale LLM sending `?event=<slug>`
      # should still produce a valid, empty proposal rather than
      # accidentally binding to a field.
      parsed = ChatUpdate.parse(%{"event" => "some-slug"})
      refute Map.has_key?(parsed, :event_slug)
    end
  end

  describe "parse/1 — encoded shortcut" do
    # Equivalence is the whole contract: sending `encoded=<b64 of qs>`
    # must produce the same ChatUpdate as sending `qs` unencoded.
    test "URL-safe base64 with padding decodes to the same result" do
      qs = "names[0]=Alice&checks[0]=1"
      encoded = Base.url_encode64(qs)

      via_encoded = ChatUpdate.parse(%{"encoded" => encoded})
      via_raw = ChatUpdate.parse(Plug.Conn.Query.decode(qs))

      assert via_encoded == via_raw
    end

    test "URL-safe base64 without padding also decodes" do
      qs = "names[0]=Alice"
      encoded = Base.url_encode64(qs, padding: false)

      assert %ChatUpdate{main_rows: [%Row{index: 0, name: "Alice"}]} =
               ChatUpdate.parse(%{"encoded" => encoded})
    end

    test "standard base64 falls back cleanly for LLMs that don't reach for URL-safe" do
      qs = "names[0]=Bob"
      encoded = Base.encode64(qs)

      assert %ChatUpdate{main_rows: [%Row{index: 0, name: "Bob"}]} =
               ChatUpdate.parse(%{"encoded" => encoded})
    end

    test "nested query params survive the round-trip" do
      qs = "names[0]=Alice&fields[0][tamanho]=M&checks[0]=1&capacity=6"
      encoded = Base.url_encode64(qs)

      assert %ChatUpdate{
               main_rows: [row],
               main_capacity: 6
             } = ChatUpdate.parse(%{"encoded" => encoded})

      assert row.name == "Alice"
      assert row.values == %{"tamanho" => "M"}
      assert row.paid == true
    end

    test "malformed base64 collapses to an empty ChatUpdate (no 500)" do
      assert %ChatUpdate{main_rows: [], wait_rows: []} =
               ChatUpdate.parse(%{"encoded" => "not_valid_base64!@#$%"})
    end

    test "encoded values win on collision with sibling query params" do
      # Sibling `names[0]=Zoe` is overridden by encoded `names[0]=Alice`.
      qs = "names[0]=Alice"
      encoded = Base.url_encode64(qs)

      params = %{"encoded" => encoded, "names" => %{"0" => "Zoe"}}

      assert %ChatUpdate{main_rows: [%Row{name: "Alice"}]} = ChatUpdate.parse(params)
    end

    test "absent / empty encoded is a no-op" do
      assert %ChatUpdate{main_rows: [%Row{name: "Alice"}]} =
               ChatUpdate.parse(%{"encoded" => "", "names" => %{"0" => "Alice"}})
    end
  end

  describe "compact aliases — positional names" do
    # Equivalence is the whole contract: `n=A|B|C` must parse to the
    # same result as `names[0]=A&names[1]=B&names[2]=C`.
    test "n=A|B|C decodes to the same result as the long form" do
      via_short = ChatUpdate.parse(%{"n" => "Alice|Bruno|Camila"})

      via_long =
        ChatUpdate.parse(%{
          "names" => %{"0" => "Alice", "1" => "Bruno", "2" => "Camila"}
        })

      assert via_short == via_long
    end

    test "empty position clears the slot (n=A||C)" do
      assert %ChatUpdate{main_rows: rows} = ChatUpdate.parse(%{"n" => "Alice||Camila"})

      # Slot 1 is an explicit empty — same semantics as `names[1]=`.
      assert [
               %Row{index: 0, name: "Alice"},
               %Row{index: 1, name: ""},
               %Row{index: 2, name: "Camila"}
             ] = rows
    end

    test "wn=A|B populates wait rows" do
      assert %ChatUpdate{wait_rows: [%Row{name: "Ana"}, %Row{name: "Bia"}]} =
               ChatUpdate.parse(%{"wn" => "Ana|Bia"})
    end

    test "long form wins at conflicting indices" do
      # `n=Alice|Bruno|Camila` puts Bruno at slot 1;
      # `names[1]=Zoe` overrides Bruno with Zoe.
      parsed =
        ChatUpdate.parse(%{
          "n" => "Alice|Bruno|Camila",
          "names" => %{"1" => "Zoe"}
        })

      assert %ChatUpdate{main_rows: rows} = parsed
      names = Enum.map(rows, &{&1.index, &1.name})

      assert names == [{0, "Alice"}, {1, "Zoe"}, {2, "Camila"}]
    end
  end

  describe "compact aliases — paid bitmap" do
    test "c=1101 sets paid on the marked slots" do
      assert %ChatUpdate{main_rows: rows} =
               ChatUpdate.parse(%{"n" => "A|B|C|D", "c" => "1101"})

      paid = Enum.map(rows, &{&1.index, &1.paid})
      assert paid == [{0, true}, {1, true}, {2, false}, {3, true}]
    end

    test "c=1-0 leaves the `-` slot as unspecified (nil)" do
      assert %ChatUpdate{main_rows: rows} =
               ChatUpdate.parse(%{"n" => "A|B|C", "c" => "1-0"})

      paid = Enum.map(rows, &{&1.index, &1.paid})
      # Slot 1 is `-` — nil in the row so the applier leaves the row's
      # existing paid flag alone.
      assert paid == [{0, true}, {1, nil}, {2, false}]
    end

    test "y and n are accepted as synonyms for 1 and 0" do
      assert %ChatUpdate{main_rows: rows} =
               ChatUpdate.parse(%{"n" => "A|B|C", "c" => "y-n"})

      paid = Enum.map(rows, &{&1.index, &1.paid})
      assert paid == [{0, true}, {1, nil}, {2, false}]
    end

    test "wc populates the wait rows' paid flags" do
      assert %ChatUpdate{wait_rows: rows} =
               ChatUpdate.parse(%{"wn" => "X|Y|Z", "wc" => "10-"})

      paid = Enum.map(rows, &{&1.index, &1.paid})
      assert paid == [{0, true}, {1, false}, {2, nil}]
    end

    test "long form wins at conflicting indices" do
      parsed =
        ChatUpdate.parse(%{
          "n" => "A|B|C",
          "c" => "111",
          # Override slot 1 via long form.
          "checks" => %{"1" => "0"}
        })

      paid = parsed.main_rows |> Enum.map(&{&1.index, &1.paid})
      assert paid == [{0, true}, {1, false}, {2, true}]
    end
  end

  describe "compact aliases — scalar and nested" do
    test "k= is an alias for capacity=" do
      assert %ChatUpdate{main_capacity: 25} = ChatUpdate.parse(%{"k" => "25"})
    end

    test "long capacity= wins over short k=" do
      assert %ChatUpdate{main_capacity: 30} =
               ChatUpdate.parse(%{"k" => "25", "capacity" => "30"})
    end

    test "e= is an alias for encoded=" do
      qs = "n=Alice|Bruno&c=11"
      encoded = Base.url_encode64(qs)

      assert %ChatUpdate{main_rows: rows} = ChatUpdate.parse(%{"e" => encoded})

      names = Enum.map(rows, & &1.name)
      assert names == ["Alice", "Bruno"]
    end

    test "f is an alias for fields (same nested shape)" do
      via_short = ChatUpdate.parse(%{"f" => %{"0" => %{"tamanho" => "M"}}})
      via_long = ChatUpdate.parse(%{"fields" => %{"0" => %{"tamanho" => "M"}}})
      assert via_short == via_long
    end

    test "long fields[i][k]= overrides short f[i][k]= at that key" do
      parsed =
        ChatUpdate.parse(%{
          "f" => %{"0" => %{"tamanho" => "M", "numero" => "10"}},
          "fields" => %{"0" => %{"tamanho" => "G"}}
        })

      # Slot 0's `tamanho` overridden to G, `numero` preserved from `f`.
      assert %ChatUpdate{main_rows: [row]} = parsed
      assert row.values == %{"tamanho" => "G", "numero" => "10"}
    end

    test "fl is an alias for field_labels" do
      parsed =
        ChatUpdate.parse(%{
          "f" => %{"0" => %{"nome-na-camisa" => "Alice"}},
          "fl" => %{"nome-na-camisa" => "Nome na camisa"}
        })

      assert parsed.field_labels == %{"nome-na-camisa" => "Nome na camisa"}
    end
  end

  describe "compact aliases — stacking" do
    test "aliases inside a base64-encoded payload also work" do
      # This is the big-win combo: base64 wraps a compact-alias query.
      qs = "n=Alice|Bruno|Camila&c=110&k=6"
      encoded = Base.url_encode64(qs)

      assert %ChatUpdate{
               main_rows: rows,
               main_capacity: 6
             } = ChatUpdate.parse(%{"e" => encoded})

      pairs = Enum.map(rows, &{&1.index, &1.name, &1.paid})

      assert pairs == [
               {0, "Alice", true},
               {1, "Bruno", true},
               {2, "Camila", false}
             ]
    end

    test "a 24-attendee compact URL roundtrips end-to-end" do
      # The load-bearing case for shipping this feature.
      names = for i <- 1..24, do: "P#{i}"
      n = Enum.join(names, "|")
      c = String.duplicate("1", 24)

      parsed = ChatUpdate.parse(%{"n" => n, "c" => c})

      assert length(parsed.main_rows) == 24
      assert Enum.map(parsed.main_rows, & &1.name) == names
      assert Enum.all?(parsed.main_rows, & &1.paid)
    end
  end

  describe "expand_encoded/1" do
    test "strips the `encoded` key from the returned params so picker links stay readable" do
      qs = "names[0]=Alice"
      encoded = Base.url_encode64(qs)

      expanded = ChatUpdate.expand_encoded(%{"encoded" => encoded, "capacity" => "5"})

      # The blob is gone — the LiveView is meant to use this for the
      # `raw_params` it embeds into picker hrefs, and shipping the
      # opaque form there would defeat the purpose.
      refute Map.has_key?(expanded, "encoded")
      # Decoded content merged in.
      assert Map.get(expanded, "names") == %{"0" => "Alice"}
      # Sibling params preserved.
      assert Map.get(expanded, "capacity") == "5"
    end

    test "no `encoded` present — returns params unchanged" do
      params = %{"names" => %{"0" => "Alice"}}
      assert ChatUpdate.expand_encoded(params) == params
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

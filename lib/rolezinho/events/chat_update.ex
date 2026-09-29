defmodule Rolezinho.Events.ChatUpdate do
  @moduledoc """
  Parses an LLM-generated query string into a structured proposal the
  `/atualizar` screen can render as a diff.

  An LLM watching a group chat can't call our API, but it *can* build a
  URL. This module is the contract that turns those URLs into something
  the LiveView can reason about, and later apply via
  `Rolezinho.Events.apply_chat_update/3`.

  ## Query param format

  Slot indices are **0-based**. Position `i` maps to the `i`-th slot of
  the event's main list (or wait list, for the `wait_*` family).

    * `names[<i>]` — the attendee's name at slot `i`. Missing name for a
      slot means "leave whatever is there alone".
    * `fields[<i>][<key>]` — value for the custom form field `key`.
      The key is matched case-insensitively against the event's
      existing `form_fields` (by id and by slugified label). A key
      that matches nothing is surfaced as a **suggested new field**,
      which the human confirming the update can create or discard.
    * `checks[<i>]` — paid checkbox. Truthy values (`1`, `true`, `yes`,
      `on`) mark the row paid; falsy values (`0`, `false`, `""`) clear
      it; absent means the current paid flag is preserved.
    * `wait_names[<i>]`, `wait_checks[<i>]`, `wait_fields[<i>][<key>]` —
      same shape as the main-list families, targeting the wait list.
      Not every chat has a wait list; when absent, the wait list is
      untouched. Custom fields on wait rows share the same event-wide
      form-field definitions as the main list.
    * `event=<slug>` — optional. When present, `/atualizar` skips the
      event picker.
    * `capacity=<N>` — optional. Proposes a new main-list size. The
      LiveView surfaces it as an editable number the human can
      override. Grows freely; shrink clamps at the number of filled
      slots (nobody is dropped by a resize alone — the URL has to
      explicitly clear the extra slots first).
    * `field_labels[<key>]=<Human Label>` — optional. When a
      `fields[i][<key>]` names a field that doesn't exist yet, the
      confirm flow creates it. This param lets the LLM keep the
      original human casing of the label ("Nome na camisa") instead
      of falling back to a title-cased dash-split of the slug key
      ("Nome Na Camisa").

  A missing `names[<i>]` means "slot `i` is unspecified". An **explicit
  empty** `names[<i>]=` means "clear slot `i`". This lets an LLM express
  a full-list rewrite by sending every slot, and an incremental patch
  by sending only the slots it saw.

  ## Return shape

  `parse/1` returns `%__MODULE__{}`:

    * `:event_slug` — string or nil.
    * `:main_rows`, `:wait_rows` — sorted lists of `%Row{}` (`:index`
      is the 0-based slot; missing values are nil).
    * `:field_keys` — every custom-field key seen across all rows, in
      first-appearance order. `/atualizar` reconciles these against
      the event's existing fields to decide which are new.

  The module does no permission check and no DB write — that's the
  LiveView's / context's job. This is a pure translation from
  `Plug.Conn.Query`-decoded params into a normalized shape.
  """

  defmodule Row do
    @moduledoc """
    One slot's proposal.

    All three optional fields are tri-state:

      * `nil` — the URL said nothing about this attribute; keep current.
      * `""` (name) or an empty map (values) — the URL explicitly
        cleared it.
      * a value — replace.

    `:index` is the 0-based slot position; the LiveView translates to
    the 1-based indices the rest of the domain uses.
    """
    defstruct [:index, :name, :values, :paid]

    @type t :: %__MODULE__{
            index: non_neg_integer(),
            name: String.t() | nil,
            values: map() | nil,
            paid: boolean() | nil
          }
  end

  defstruct event_slug: nil,
            main_rows: [],
            wait_rows: [],
            field_keys: [],
            field_labels: %{},
            main_capacity: nil

  @type t :: %__MODULE__{
          event_slug: String.t() | nil,
          main_rows: [Row.t()],
          wait_rows: [Row.t()],
          field_keys: [String.t()],
          field_labels: %{optional(String.t()) => String.t()},
          main_capacity: pos_integer() | nil
        }

  @doc """
  Parses a decoded query-params map (as delivered by Phoenix) into a
  `%ChatUpdate{}`.

  Silently drops malformed entries — an LLM that sends `names[abc]=X`
  or `fields[0]=notamap` produces a proposal that ignores those bits
  rather than a 500. The user still sees the good parts.
  """
  @spec parse(map()) :: t()
  def parse(params) when is_map(params) do
    main_rows = collect_rows(params, "names", "fields", "checks")
    wait_rows = collect_rows(params, "wait_names", "wait_fields", "wait_checks")

    %__MODULE__{
      event_slug: parse_slug(Map.get(params, "event")),
      main_rows: main_rows,
      wait_rows: wait_rows,
      # Field keys come from both lists — the same event-wide field
      # set applies to main and wait, so a key mentioned only on the
      # wait side still counts as "new field to create".
      field_keys: gather_field_keys(main_rows ++ wait_rows),
      field_labels: parse_field_labels(Map.get(params, "field_labels")),
      main_capacity: parse_capacity(Map.get(params, "capacity"))
    }
  end

  def parse(_), do: %__MODULE__{}

  # Builds the row list from the three parallel param families.
  # `fields_key` is nullable so the wait-list variant can skip custom
  # fields (they don't apply there in the current data model).
  defp collect_rows(params, names_key, fields_key, checks_key) do
    names = parse_indexed(Map.get(params, names_key))
    fields = parse_indexed_nested(Map.get(params, fields_key))
    checks = parse_indexed(Map.get(params, checks_key))

    indices =
      [names, fields, checks]
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()
      |> Enum.sort()

    Enum.map(indices, fn index ->
      %Row{
        index: index,
        name: normalize_name(Map.get(names, index)),
        values: normalize_values(Map.get(fields, index)),
        paid: normalize_paid(Map.get(checks, index))
      }
    end)
  end

  # `%{"0" => "Alice", "1" => "Bob"}` → `%{0 => "Alice", 1 => "Bob"}`.
  # Also handles the list-shaped variant Plug sometimes produces
  # (`["Alice", "Bob"]`) and the "nothing at all" case.
  defp parse_indexed(nil), do: %{}
  defp parse_indexed(value) when is_binary(value), do: %{}

  defp parse_indexed(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      case to_index(k) do
        {:ok, i} -> Map.put(acc, i, v)
        :error -> acc
      end
    end)
  end

  defp parse_indexed(list) when is_list(list) do
    list
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {v, i}, acc -> Map.put(acc, i, v) end)
  end

  defp parse_indexed(_), do: %{}

  # `%{"0" => %{"shirt" => "M"}}` shape. Anything not a map at the
  # inner level is dropped so a bogus `fields[0]=oops` doesn't
  # explode.
  defp parse_indexed_nested(nil), do: %{}

  defp parse_indexed_nested(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, inner}, acc ->
      with {:ok, i} <- to_index(k),
           true <- is_map(inner) do
        cleaned =
          inner
          |> Enum.reduce(%{}, fn {key, value}, inner_acc ->
            key = normalize_field_key(key)

            cond do
              key == "" -> inner_acc
              not is_binary(value) -> inner_acc
              true -> Map.put(inner_acc, key, String.trim(value))
            end
          end)

        if cleaned == %{}, do: acc, else: Map.put(acc, i, cleaned)
      else
        _ -> acc
      end
    end)
  end

  defp parse_indexed_nested(_), do: %{}

  defp to_index(k) when is_integer(k) and k >= 0, do: {:ok, k}

  defp to_index(k) when is_binary(k) do
    case Integer.parse(k) do
      {i, ""} when i >= 0 -> {:ok, i}
      _ -> :error
    end
  end

  defp to_index(_), do: :error

  # `nil` = absent (leave slot alone). Otherwise trim; an explicit
  # empty means "clear the slot".
  defp normalize_name(nil), do: nil
  defp normalize_name(value) when is_binary(value), do: String.trim(value)
  defp normalize_name(_), do: nil

  defp normalize_values(nil), do: nil
  defp normalize_values(map) when is_map(map) and map_size(map) == 0, do: nil
  defp normalize_values(map) when is_map(map), do: map
  defp normalize_values(_), do: nil

  # Truthy: 1/true/yes/on/y. Falsy: 0/false/no/off/n/"". Anything else
  # is treated as "unspecified" — a robots-being-lazy scenario where
  # the LLM sent something we don't recognise shouldn't flip anyone's
  # paid flag by accident.
  defp normalize_paid(nil), do: nil

  defp normalize_paid(value) when is_binary(value) do
    case value |> String.trim() |> String.downcase() do
      v when v in ["1", "true", "yes", "on", "y", "sim", "s"] -> true
      v when v in ["0", "false", "no", "off", "n", "não", "nao", ""] -> false
      _ -> nil
    end
  end

  defp normalize_paid(true), do: true
  defp normalize_paid(false), do: false
  defp normalize_paid(_), do: nil

  # Slug rules mirror what `Rolezinho.Event.FormField.build_id/2` does
  # to labels, so an LLM that sends a Portuguese key like "Nome na
  # camisa" matches a field the organizer labeled that way. Both
  # paths must produce byte-identical output for the reconciliation
  # to work — keep them in sync.
  @doc """
  Normalizes an incoming field key the same way form-field ids are
  built (`Rolezinho.Event.FormField.build_id/2`). Public so the
  LiveView can perform the same reconciliation when it decides
  whether a key names an existing field.
  """
  @spec normalize_field_key(String.t() | atom() | nil) :: String.t()
  def normalize_field_key(nil), do: ""

  def normalize_field_key(key) when is_atom(key),
    do: key |> Atom.to_string() |> normalize_field_key()

  def normalize_field_key(key) when is_binary(key) do
    key
    |> String.trim()
    |> String.downcase()
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

  def normalize_field_key(_), do: ""

  defp parse_slug(nil), do: nil

  defp parse_slug(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp parse_slug(_), do: nil

  # `capacity=15` → 15. Anything non-positive or non-integer collapses
  # to nil so the LiveView falls back to the event's current capacity
  # (and to whatever the max explicit index in the URL would demand).
  defp parse_capacity(nil), do: nil

  defp parse_capacity(value) when is_integer(value) and value > 0, do: value

  defp parse_capacity(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} when n > 0 -> n
      _ -> nil
    end
  end

  defp parse_capacity(_), do: nil

  # `field_labels[shirt]=Camisa` → %{"shirt" => "Camisa"}. Keys are
  # normalized the same way `fields[<i>][<key>]` are, so a lookup
  # from a `fields` key always matches a `field_labels` key from the
  # same URL.
  defp parse_field_labels(nil), do: %{}

  defp parse_field_labels(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {raw_key, raw_label}, acc ->
      key = normalize_field_key(raw_key)

      cond do
        key == "" ->
          acc

        not is_binary(raw_label) ->
          acc

        true ->
          case String.trim(raw_label) do
            "" -> acc
            label -> Map.put(acc, key, label)
          end
      end
    end)
  end

  defp parse_field_labels(_), do: %{}

  # Unique field keys, in row order across rows. Within a single
  # row, key order matches whatever Map iteration returns (Elixir
  # maps are not insertion-ordered) — stable enough for the LiveView
  # to show chips in a repeatable order for a given URL, but not
  # something a test should assert on "first appearance in the URL".
  defp gather_field_keys(rows) do
    rows
    |> Enum.reduce([], fn %Row{values: values}, acc ->
      case values do
        nil -> acc
        map when is_map(map) -> acc ++ Enum.reject(Map.keys(map), &(&1 in acc))
      end
    end)
  end
end

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
    * `encoded=<base64>` — optional. A URL escape hatch for long
      chats. The decoded value is the *exact same query string* the
      LLM would otherwise assemble longhand — `parse/1` expands it
      transparently and continues as normal. URL-safe base64 preferred
      (`-` / `_` in place of `+` / `/`), padding optional; standard
      base64 is also accepted. Any other query params sent alongside
      `encoded` are merged in, with the decoded values winning on
      collision.

  ## Compact aliases

  For long lists, the parser also accepts a set of compact aliases
  that shrink the URL substantially:

  | Compact | Long | Notes |
  |---|---|---|
  | `n=A\|B\|C` | `names[0]=A&names[1]=B&names[2]=C` | Pipe-separated, positional. Empty position (`A\|\|C`) clears that slot. |
  | `wn=A\|B` | `wait_names[0]=A&wait_names[1]=B` | Same for the wait list. |
  | `c=1101-` | `checks[0]=1&checks[1]=1&checks[2]=0&checks[3]=1` | Paid bitmap. `1`/`y` = true, `0`/`n` = false, anything else = leave alone. |
  | `wc=…` | `wait_checks[…]=…` | Same for the wait list. |
  | `f`, `wf`, `fl` | `fields`, `wait_fields`, `field_labels` | Same nested shape, shorter key. |
  | `k=15` | `capacity=15` | |
  | `e=<base64>` | `encoded=<base64>` | |

  Precedence when both a short and its long form set a value at the
  same slot: **the long form wins**. Same-family shorts and longs
  merge additively so a URL can pin one specific slot with the long
  form while keeping the bulk compact.

  A missing `names[<i>]` means "slot `i` is unspecified". An **explicit
  empty** `names[<i>]=` means "clear slot `i`". This lets an LLM express
  a full-list rewrite by sending every slot, and an incremental patch
  by sending only the slots it saw.

  ## Return shape

  `parse/1` returns `%__MODULE__{}`:

    * `:main_rows`, `:wait_rows` — sorted lists of `%Row{}` (`:index`
      is the 0-based slot; missing values are nil).
    * `:field_keys` — every custom-field key seen across all rows.
      `/atualizar` reconciles these against the event's existing
      fields to decide which are new.
    * `:field_labels` — optional map of `%{slug_key => human_label}`
      the LLM can send to preserve the original casing of a new
      field's label.
    * `:main_capacity` — optional integer proposing a new list size.

  The URL never carries the event slug — the LiveView routes on
  `/atualizar/:slug` for the diff view and `/atualizar` for the
  picker, so the LLM's URL is event-agnostic. The picker is what
  binds a proposal to a specific event.

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

  defstruct main_rows: [],
            wait_rows: [],
            field_keys: [],
            field_labels: %{},
            main_capacity: nil

  @type t :: %__MODULE__{
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
    # Three-step pipeline:
    #
    #   1. expand_aliases — promotes the `e=` alias to `encoded=` so
    #      the next step can see it, plus expands the other compact
    #      shorts (`n=`, `c=`, `k=`, etc.).
    #   2. expand_encoded — base64-decodes the (now-promoted)
    #      `encoded=` param and merges its decoded query into the
    #      top-level params.
    #   3. expand_aliases — second pass to expand any compact shorts
    #      that lived *inside* the base64 payload. Idempotent when
    #      no aliases are present.
    #
    # This is what lets an LLM stack the two — the recommended
    # "maximum compression" URL is `?e=<base64 of n=A|B|C&c=110>`.
    params =
      params
      |> expand_aliases()
      |> expand_encoded()
      |> expand_aliases()

    main_rows = collect_rows(params, "names", "fields", "checks")
    wait_rows = collect_rows(params, "wait_names", "wait_fields", "wait_checks")

    %__MODULE__{
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

  @doc """
  Expands the `encoded=<base64>` shortcut into a plain params map.

  Idempotent when `encoded` is absent — returns `params` unchanged.
  When present, decodes the value (URL-safe first, then standard
  base64 as a fallback), treats the result as a query string, merges
  it over any other params (encoded wins on collision), and drops
  the `encoded` key itself from the result. Malformed base64 is a
  silent no-op that returns the params minus the bad `encoded` key,
  so a fat-fingered LLM string doesn't 500 the picker.

  The LiveView calls this before storing `raw_params` so picker
  links carry the readable query string instead of the opaque blob.
  """
  @spec expand_encoded(map()) :: map()
  def expand_encoded(params) when is_map(params) do
    case Map.pop(params, "encoded") do
      {value, remainder} when is_binary(value) and value != "" ->
        case decode_query(value) do
          {:ok, decoded_map} -> Map.merge(remainder, decoded_map)
          :error -> remainder
        end

      {_, remainder} ->
        remainder
    end
  end

  def expand_encoded(other), do: other

  @doc """
  Expands the compact aliases into their long-form equivalents.

  See the module doc's "Compact aliases" section for the full table
  and precedence rules. Idempotent when no aliases are present.

  This is public so the LiveView could call it on `raw_params` if it
  ever needed to — today the LiveView keeps the compact form for
  picker-link URLs (expanding would blow up the URL length, which
  is the whole point of the aliases).
  """
  @spec expand_aliases(map()) :: map()
  def expand_aliases(params) when is_map(params) do
    params
    |> expand_scalar_alias("k", "capacity")
    |> expand_scalar_alias("e", "encoded")
    |> expand_nested_alias("f", "fields")
    |> expand_nested_alias("wf", "wait_fields")
    |> expand_nested_alias("fl", "field_labels")
    |> expand_positional("n", "names")
    |> expand_positional("wn", "wait_names")
    |> expand_bitmap("c", "checks")
    |> expand_bitmap("wc", "wait_checks")
  end

  def expand_aliases(other), do: other

  # Scalar alias: `k=15` → `capacity=15`. The long form wins if both
  # are present.
  defp expand_scalar_alias(params, short, long) do
    case Map.pop(params, short) do
      {nil, remainder} ->
        remainder

      {value, remainder} ->
        if Map.has_key?(remainder, long),
          do: remainder,
          else: Map.put(remainder, long, value)
    end
  end

  # Nested alias: `f[0][shirt]=M` → `fields[0][shirt]=M`. Two nested
  # maps merge additively, with the long form's per-index values
  # winning on collision (so a URL can pin one slot with `fields`
  # while carrying the rest in `f`).
  defp expand_nested_alias(params, short, long) do
    case Map.pop(params, short) do
      {nil, remainder} ->
        remainder

      {short_map, remainder} when is_map(short_map) ->
        long_map = Map.get(remainder, long, %{}) |> ensure_map()
        Map.put(remainder, long, deep_merge(short_map, long_map))

      {_, remainder} ->
        remainder
    end
  end

  # Positional list: `n=Alice|Bruno|Camila` → %{"names" =>
  # %{"0" => "Alice", "1" => "Bruno", "2" => "Camila"}}.
  # Empty positions become empty strings, which the row-clear semantics
  # already handle ("names[i]= clears slot i").
  defp expand_positional(params, short, long) do
    case Map.pop(params, short) do
      {nil, remainder} ->
        remainder

      {value, remainder} when is_binary(value) ->
        short_map =
          value
          |> String.split("|")
          |> Enum.with_index()
          |> Map.new(fn {name, i} -> {Integer.to_string(i), name} end)

        long_map = Map.get(remainder, long, %{}) |> ensure_map()
        Map.put(remainder, long, Map.merge(short_map, long_map))

      {_, remainder} ->
        remainder
    end
  end

  # Paid bitmap: `c=1101-` → %{"checks" => %{"0" => "1", "1" => "1",
  # "2" => "0", "3" => "1"}}. The tri-state "unspecified" (any char
  # that isn't 1/0/y/n) is expressed by *omitting* the index from the
  # map — the parser's own tri-state handling then treats it as
  # "leave alone".
  defp expand_bitmap(params, short, long) do
    case Map.pop(params, short) do
      {nil, remainder} ->
        remainder

      {value, remainder} when is_binary(value) ->
        short_map =
          value
          |> String.graphemes()
          |> Enum.with_index()
          |> Enum.reduce(%{}, fn {char, i}, acc ->
            case bitmap_char(char) do
              nil -> acc
              v -> Map.put(acc, Integer.to_string(i), v)
            end
          end)

        long_map = Map.get(remainder, long, %{}) |> ensure_map()
        Map.put(remainder, long, Map.merge(short_map, long_map))

      {_, remainder} ->
        remainder
    end
  end

  defp bitmap_char("1"), do: "1"
  defp bitmap_char("y"), do: "1"
  defp bitmap_char("Y"), do: "1"
  defp bitmap_char("0"), do: "0"
  defp bitmap_char("n"), do: "0"
  defp bitmap_char("N"), do: "0"
  # Every other char (`-`, `.`, `x`, whitespace, etc.) is "unspecified".
  # Omitting the index from the resulting map is what makes the row
  # parser's `normalize_paid/1` fall through to `nil` ("leave alone").
  defp bitmap_char(_), do: nil

  # Two-level deep merge for nested maps like `fields[0][shirt]=M`.
  # Merges the outer index-keyed map, and for a shared index merges
  # the inner key-keyed map — with the second argument ("long")
  # winning on collision.
  defp deep_merge(short_outer, long_outer) do
    Map.merge(short_outer, long_outer, fn _index, short_inner, long_inner ->
      cond do
        is_map(short_inner) and is_map(long_inner) -> Map.merge(short_inner, long_inner)
        true -> long_inner
      end
    end)
  end

  defp ensure_map(m) when is_map(m), do: m
  defp ensure_map(_), do: %{}

  # URL-safe base64 first (that's what `Base.url_encode64/2` produces
  # and what an LLM should ideally use to keep the URL free of chars
  # that would need percent-encoding). Standard base64 as a fallback
  # so an LLM that reached for `Base.encode64/1` also works.
  defp decode_query(value) do
    with :error <- try_decode(value, &Base.url_decode64(&1, padding: false)),
         :error <- try_decode(value, &Base.decode64(&1, padding: false)) do
      :error
    end
  end

  defp try_decode(value, decoder) do
    case decoder.(value) do
      {:ok, decoded} when is_binary(decoded) -> {:ok, Plug.Conn.Query.decode(decoded)}
      _ -> :error
    end
  end

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

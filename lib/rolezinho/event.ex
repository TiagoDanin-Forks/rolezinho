defmodule Rolezinho.Event do
  @moduledoc """
  Represents a Rolezinho (event).

  Parses and serializes the markdown file that persists the event.
  The parser is intentionally forgiving so admins can freely edit the raw
  markdown while the app still recognizes the attendee/wait lists.

  File layout produced by `render/1`:

      # TITLE

      <free-form header text>

      1- Person ✅
      2- Other
      ...
      N-

      Lista de reserva
      1- ...

      <free-form footer text>
  """

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee

  defstruct slug: nil,
            status: :active,
            title: "",
            header: "",
            main_capacity: 0,
            main_list: [],
            wait_enabled: false,
            wait_intro: "Lista de reserva",
            wait_list: [],
            footer: ""

  @type status :: :active | :hidden | :done

  @type t :: %__MODULE__{
          slug: String.t() | nil,
          status: status(),
          title: String.t(),
          header: String.t(),
          main_capacity: non_neg_integer(),
          main_list: [Attendee.t()],
          wait_enabled: boolean(),
          wait_intro: String.t(),
          wait_list: [Attendee.t()],
          footer: String.t()
        }

  @paid_marks ["✅️", "✅"]
  @item_regex ~r/^\s*(\d+)\s*[-.\)]\s*(.*)$/u

  @doc """
  Parses a markdown string into an %Event{}.
  """
  @spec parse(String.t(), keyword()) :: t()
  def parse(content, opts \\ []) when is_binary(content) do
    slug = Keyword.get(opts, :slug)
    status = Keyword.get(opts, :status, :active)

    lines = String.split(content, ~r/\r?\n/)

    {title, rest} = extract_title(lines)
    {header_lines, list1_lines, between_lines, list2_lines, footer_lines} = split_sections(rest)

    {main_capacity, main_list} = parse_list(list1_lines)
    wait_enabled = list2_lines != []
    {_wait_capacity, wait_list_padded} = parse_list(list2_lines)

    # The wait list is conceptually infinite; drop empty trailing slots and
    # ignore empty in-between slots. Only real attendees are kept.
    wait_list =
      Enum.filter(wait_list_padded, fn %Attendee{name: n} -> String.trim(n) != "" end)

    wait_intro =
      between_lines
      |> Enum.join("\n")
      |> String.trim()
      |> case do
        "" -> "Lista de reserva"
        other -> other
      end

    %Event{
      slug: slug,
      status: status,
      title: title,
      header: header_lines |> Enum.join("\n") |> String.trim("\n"),
      main_capacity: main_capacity,
      main_list: main_list,
      wait_enabled: wait_enabled,
      wait_intro: wait_intro,
      wait_list: wait_list,
      footer: footer_lines |> Enum.join("\n") |> String.trim("\n")
    }
  end

  @doc """
  Serializes an %Event{} back into markdown.
  """
  @spec render(t()) :: String.t()
  def render(%Event{} = event) do
    title_line = "# " <> String.trim(event.title || "")

    parts = [title_line]

    parts =
      if event.header != "" and event.header != nil do
        parts ++ ["", event.header]
      else
        parts
      end

    parts = parts ++ ["", render_list(event.main_list, event.main_capacity)]

    parts =
      if event.wait_enabled do
        intro = event.wait_intro |> to_string() |> String.trim()
        intro = if intro == "", do: "Lista de reserva", else: intro
        parts ++ ["", intro, render_wait_list(event.wait_list)]
      else
        parts
      end

    parts =
      if event.footer != "" and event.footer != nil do
        parts ++ ["", event.footer]
      else
        parts
      end

    parts
    |> Enum.join("\n")
    |> String.trim_trailing()
    |> Kernel.<>("\n")
  end

  @doc """
  Produces the shareable/raw text representation people can copy or share.

  Prepends the given URL as the first line, drops the leading `# ` from the title,
  and replaces empty list slots with a compact summary line:

    * `3 vagas: <url>` (or `1 vaga: <url>`) after the main list when there is
      still room. Nothing is added when the main list is full.
    * `Entrar na espera: <url>` after the wait list (always present when the
      wait list is enabled, since it is infinite).

  The persisted markdown file is unaffected by this — see `render/1`.
  """
  @spec to_text(t(), String.t() | nil) :: String.t()
  def to_text(%Event{} = event, url \\ nil) do
    title_line = String.trim(event.title || "")

    parts =
      case url do
        nil -> []
        "" -> []
        u -> [u, ""]
      end

    parts = parts ++ [title_line]

    parts =
      if event.header != "" and event.header != nil do
        parts ++ ["", event.header]
      else
        parts
      end

    parts = parts ++ ["", main_list_text(event, url)]

    parts =
      if event.wait_enabled do
        intro = event.wait_intro |> to_string() |> String.trim()
        intro = if intro == "", do: "Lista de reserva", else: intro
        parts ++ ["", intro, wait_list_text(event, url)]
      else
        parts
      end

    parts =
      if event.footer != "" and event.footer != nil do
        parts ++ ["", event.footer]
      else
        parts
      end

    parts
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    |> String.trim_trailing()
    |> Kernel.<>("\n")
  end

  defp main_list_text(%Event{} = event, url) do
    filled = compact_main(event.main_list)
    free = event.main_capacity - length(filled)

    lines =
      filled
      |> Enum.with_index(1)
      |> Enum.map(fn {%Attendee{} = att, i} -> render_attendee_line(i, att) end)

    lines =
      if free > 0 do
        lines ++ [vagas_line(free, url)]
      else
        lines
      end

    Enum.join(lines, "\n")
  end

  defp wait_list_text(%Event{} = event, url) do
    lines =
      event.wait_list
      |> Enum.with_index(1)
      |> Enum.map(fn {%Attendee{} = att, i} -> render_attendee_line(i, att) end)

    Enum.join(lines ++ [entrar_espera_line(url)], "\n")
  end

  @doc false
  def vagas_line(count, url) do
    label = if count == 1, do: "1 vaga", else: "#{count} vagas"
    if is_binary(url) and url != "", do: "#{label}: #{url}", else: label
  end

  @doc false
  def entrar_espera_line(url) do
    if is_binary(url) and url != "",
      do: "Entrar na espera: #{url}",
      else: "Entrar na espera"
  end

  # ---------- List operations ----------

  @doc """
  Ensures the main list has exactly `capacity` slots (padding with empty).
  """
  @spec normalize_main(t()) :: t()
  def normalize_main(%Event{} = event) do
    filled = compact_main(event.main_list)
    capacity = max(event.main_capacity, length(filled))
    padded = pad(filled, capacity)
    %Event{event | main_capacity: capacity, main_list: padded}
  end

  @doc """
  Adds an attendee to the first empty main slot. Returns {:ok, event} or {:error, reason}.
  """
  @spec add_to_main(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def add_to_main(%Event{} = event, name) do
    name = clean_name(name)

    cond do
      name == "" ->
        {:error, :empty_name}

      main_full?(event) ->
        {:error, :main_full}

      true ->
        list = replace_first_empty(event.main_list, %Attendee{name: name, paid: false})
        {:ok, %Event{event | main_list: list}}
    end
  end

  @doc "Adds an attendee to the end of the wait list."
  @spec add_to_wait(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def add_to_wait(%Event{} = event, name) do
    name = clean_name(name)

    cond do
      name == "" ->
        {:error, :empty_name}

      not event.wait_enabled ->
        {:error, :wait_disabled}

      true ->
        {:ok, %Event{event | wait_list: event.wait_list ++ [%Attendee{name: name, paid: false}]}}
    end
  end

  @doc "Removes and shifts everyone up in the main list (1-based index)."
  @spec remove_main(t(), pos_integer()) :: t()
  def remove_main(%Event{} = event, index) do
    new_list =
      event.main_list
      |> List.delete_at(index - 1)
      |> Kernel.++([%Attendee{}])
      |> Enum.take(event.main_capacity)

    %Event{event | main_list: compact_then_pad(new_list, event.main_capacity)}
  end

  @doc "Removes an attendee from the wait list (1-based)."
  @spec remove_wait(t(), pos_integer()) :: t()
  def remove_wait(%Event{} = event, index) do
    %Event{event | wait_list: List.delete_at(event.wait_list, index - 1)}
  end

  @doc "Toggles the paid flag on a main list attendee (1-based)."
  @spec toggle_paid_main(t(), pos_integer()) :: t()
  def toggle_paid_main(%Event{} = event, index) do
    list = update_at(event.main_list, index - 1, fn att -> %{att | paid: !att.paid} end)
    %Event{event | main_list: list}
  end

  @doc "Toggles the paid flag on a wait list attendee."
  @spec toggle_paid_wait(t(), pos_integer()) :: t()
  def toggle_paid_wait(%Event{} = event, index) do
    list = update_at(event.wait_list, index - 1, fn att -> %{att | paid: !att.paid} end)
    %Event{event | wait_list: list}
  end

  @doc "Renames a main list attendee."
  @spec rename_main(t(), pos_integer(), String.t()) :: t()
  def rename_main(%Event{} = event, index, name) do
    name = clean_name(name)
    list = update_at(event.main_list, index - 1, fn att -> %{att | name: name} end)
    %Event{event | main_list: list}
  end

  @doc "Renames a wait list attendee."
  @spec rename_wait(t(), pos_integer(), String.t()) :: t()
  def rename_wait(%Event{} = event, index, name) do
    name = clean_name(name)
    list = update_at(event.wait_list, index - 1, fn att -> %{att | name: name} end)
    %Event{event | wait_list: list}
  end

  @doc "Promotes the wait list entry at `index` (1-based) to the first empty main slot."
  @spec promote(t(), pos_integer()) :: {:ok, t()} | {:error, atom()}
  def promote(%Event{} = event, index) do
    cond do
      main_full?(event) ->
        {:error, :main_full}

      Enum.at(event.wait_list, index - 1) == nil ->
        {:error, :not_found}

      true ->
        %Attendee{} = person = Enum.at(event.wait_list, index - 1)
        new_wait = List.delete_at(event.wait_list, index - 1)
        new_main = replace_first_empty(event.main_list, person)
        {:ok, %Event{event | main_list: new_main, wait_list: new_wait}}
    end
  end

  @doc """
  Resizes the main list. When growing, appends empty slots. When shrinking,
  clamps to the number of filled attendees (never removes anyone).
  """
  @spec resize_main(t(), integer()) :: t()
  def resize_main(%Event{} = event, requested) when is_integer(requested) do
    filled = compact_main(event.main_list)
    new_capacity = max(requested, length(filled))
    %Event{event | main_capacity: new_capacity, main_list: pad(filled, new_capacity)}
  end

  @doc "How many main slots are still empty."
  @spec main_free_slots(t()) :: non_neg_integer()
  def main_free_slots(%Event{} = event) do
    event.main_capacity - length(compact_main(event.main_list))
  end

  @doc "True when the main list has no empty slots."
  @spec main_full?(t()) :: boolean()
  def main_full?(%Event{} = event), do: main_free_slots(event) <= 0

  # ---------- Internal helpers ----------

  defp extract_title(lines) do
    {title, rest} =
      case Enum.split_while(lines, fn line -> not String.match?(line, ~r/^\s*#\s+/u) end) do
        {before, [title_line | rest]} ->
          title =
            title_line
            |> String.replace(~r/^\s*#+\s*/u, "")
            |> String.trim()

          # Anything before the title heading is discarded (usually just blank lines).
          _ = before
          {title, rest}

        {all, []} ->
          {"", all}
      end

    {title, drop_leading_blanks(rest)}
  end

  defp drop_leading_blanks(lines) do
    Enum.drop_while(lines, &(String.trim(&1) == ""))
  end

  defp split_sections(lines) do
    {header, after_header} =
      Enum.split_while(lines, fn line -> not is_list_item?(line) end)

    {list1, after_list1} = take_list(after_header)

    {between, after_between} =
      Enum.split_while(after_list1, fn line -> not is_list_item?(line) end)

    case take_list(after_between) do
      {[], _} ->
        {trim_edges(header), list1, [], [], trim_edges(after_list1)}

      {list2, footer} ->
        {trim_edges(header), list1, trim_edges(between), list2, trim_edges(footer)}
    end
  end

  defp take_list(lines), do: Enum.split_while(lines, &is_list_item?/1)

  defp is_list_item?(line), do: String.match?(line, @item_regex)

  defp trim_edges(lines) do
    lines
    |> Enum.drop_while(&(String.trim(&1) == ""))
    |> Enum.reverse()
    |> Enum.drop_while(&(String.trim(&1) == ""))
    |> Enum.reverse()
  end

  defp parse_list([]), do: {0, []}

  defp parse_list(lines) do
    parsed =
      Enum.map(lines, fn line ->
        [_, num_str, rest] = Regex.run(@item_regex, line)
        {String.to_integer(num_str), parse_attendee(rest)}
      end)

    capacity =
      parsed
      |> Enum.map(&elem(&1, 0))
      |> Enum.max(fn -> 0 end)
      |> max(length(parsed))

    by_index =
      parsed
      |> Enum.map(fn {n, att} -> {n, att} end)
      |> Enum.into(%{})

    list =
      for i <- 1..capacity do
        Map.get(by_index, i, %Attendee{})
      end

    {capacity, list}
  end

  defp parse_attendee(text) do
    text = String.trim(text || "")

    {text, paid} =
      Enum.reduce(@paid_marks, {text, false}, fn mark, {acc, paid?} ->
        if String.contains?(acc, mark) do
          {String.replace(acc, mark, ""), true}
        else
          {acc, paid?}
        end
      end)

    %Attendee{name: String.trim(text), paid: paid}
  end

  defp render_list(list, capacity) do
    slots = pad(compact_main(list), capacity)

    slots
    |> Enum.with_index(1)
    |> Enum.map(fn {%Attendee{} = att, i} -> render_attendee_line(i, att) end)
    |> Enum.join("\n")
  end

  defp render_wait_list([]) do
    # Emit a single empty slot so the file still contains a second numbered
    # list and re-parsing preserves `wait_enabled: true`.
    "1-"
  end

  defp render_wait_list(list) do
    list
    |> Enum.with_index(1)
    |> Enum.map(fn {%Attendee{} = att, i} -> render_attendee_line(i, att) end)
    |> Enum.join("\n")
  end

  defp render_attendee_line(i, %Attendee{name: "", paid: _}), do: "#{i}- "

  defp render_attendee_line(i, %Attendee{name: name, paid: paid}) do
    mark = if paid, do: " ✅", else: ""
    "#{i}- #{name}#{mark}"
  end

  defp compact_main(list) do
    Enum.reject(list, fn %Attendee{name: n} -> String.trim(n) == "" end)
  end

  defp compact_then_pad(list, capacity) do
    list
    |> compact_main()
    |> pad(capacity)
  end

  defp pad(list, capacity) when length(list) >= capacity, do: Enum.take(list, capacity)
  defp pad(list, capacity), do: list ++ List.duplicate(%Attendee{}, capacity - length(list))

  defp replace_first_empty(list, replacement) do
    {new, _replaced?} =
      Enum.map_reduce(list, false, fn
        att, false ->
          if String.trim(att.name) == "" do
            {replacement, true}
          else
            {att, false}
          end

        att, true ->
          {att, true}
      end)

    new
  end

  defp update_at(list, index, fun) do
    List.update_at(list, index, fn
      nil -> nil
      %Attendee{} = att -> fun.(att)
    end)
  end

  defp clean_name(nil), do: ""

  defp clean_name(name) do
    name
    |> to_string()
    |> String.replace(~r/[\r\n]+/u, " ")
    |> String.trim()
  end
end

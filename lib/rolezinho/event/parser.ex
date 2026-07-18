defmodule Rolezinho.Event.Parser do
  @moduledoc """
  Parses a markdown blob into the fields that make up an `%Rolezinho.Event{}`.

  The parser is intentionally forgiving so admins can freely edit the raw
  markdown while the app still recognizes the attendee/wait lists.

  Layout expected:

      # TITLE

      <free-form header text>

      1- Person ✅
      2- Other
      ...
      N-

      Lista de reserva
      1- ...

      <free-form footer text>

  Returns a bare map so callers can feed it into an Ecto changeset.
  """

  alias Rolezinho.Event.Attendee

  @paid_marks ["✅️", "✅"]
  @item_regex ~r/^\s*(\d+)\s*[-.\)]\s*(.*)$/u

  @type parsed :: %{
          title: String.t(),
          header: String.t(),
          footer: String.t(),
          main_capacity: non_neg_integer(),
          main_list: [Attendee.t()],
          wait_enabled: boolean(),
          wait_intro: String.t(),
          wait_list: [Attendee.t()]
        }

  @doc "Parses a markdown blob into a map of event fields."
  @spec parse(String.t()) :: parsed()
  def parse(content) when is_binary(content) do
    lines = String.split(content, ~r/\r?\n/)

    {title, rest} = extract_title(lines)
    {header_lines, list1_lines, between_lines, list2_lines, footer_lines} = split_sections(rest)

    {main_capacity, main_list} = parse_list(list1_lines)
    wait_enabled = list2_lines != []
    {_wait_capacity, wait_list_padded} = parse_list(list2_lines)

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

    %{
      title: title,
      header: header_lines |> Enum.join("\n") |> String.trim("\n"),
      footer: footer_lines |> Enum.join("\n") |> String.trim("\n"),
      main_capacity: main_capacity,
      main_list: main_list,
      wait_enabled: wait_enabled,
      wait_intro: wait_intro,
      wait_list: wait_list
    }
  end

  # ---------- internals ----------

  defp extract_title(lines) do
    {title, rest} =
      case Enum.split_while(lines, fn line -> not String.match?(line, ~r/^\s*#\s+/u) end) do
        {_before, [title_line | rest]} ->
          title =
            title_line
            |> String.replace(~r/^\s*#+\s*/u, "")
            |> String.trim()

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
    {header, after_header} = Enum.split_while(lines, fn line -> not is_list_item?(line) end)
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

    by_index = Map.new(parsed)

    list =
      for i <- 1..capacity//1 do
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
end

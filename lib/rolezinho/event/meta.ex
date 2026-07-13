defmodule Rolezinho.Event.Meta do
  @moduledoc """
  Structured metadata for an event: place (`local`), start date, and start time.

  These fields are persisted at the top of the event's markdown header using
  the canonical labels below. Any other content in the header stays untouched.

      Local: Rua Caripunas
      Data: 15/07/2026
      Horário: 19:00 (BRT)

  Everything is stored and displayed in **BRT** (America/Sao_Paulo, UTC-3).
  For calendar exports we convert to UTC internally so the ICS/Google URL is
  unambiguous.
  """

  defstruct local: nil, date: nil, time: nil

  @type t :: %__MODULE__{
          local: String.t() | nil,
          date: Date.t() | nil,
          time: Time.t() | nil
        }

  @tz "America/Sao_Paulo"
  @tz_offset_seconds -3 * 3600
  @default_duration_seconds 2 * 3600

  @local_line ~r/^\s*local\s*:\s*(.+?)\s*$/iu
  @data_line ~r/^\s*data\s*:\s*(\d{1,2})\/(\d{1,2})\/(\d{2,4})\s*$/iu
  @hora_line ~r/^\s*hor[áa]rio\s*:\s*(\d{1,2}):(\d{2}).*$/iu

  @days ~w(domingo segunda terça quarta quinta sexta sábado)
  @months ~w(janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro)

  @doc "Returns true when the meta has any field set."
  @spec any?(t()) :: boolean()
  def any?(%__MODULE__{local: nil, date: nil, time: nil}), do: false
  def any?(%__MODULE__{}), do: true

  @doc "Returns true when a date is set (needed for calendar exports)."
  @spec has_date?(t()) :: boolean()
  def has_date?(%__MODULE__{date: %Date{}}), do: true
  def has_date?(%__MODULE__{}), do: false

  @doc """
  Extracts the canonical meta lines from a header string and returns
  `{meta, header_without_meta_lines}`.
  """
  @spec extract(String.t() | nil) :: {t(), String.t()}
  def extract(nil), do: {%__MODULE__{}, ""}

  def extract(header) when is_binary(header) do
    lines = String.split(header, ~r/\r?\n/)

    {meta, kept} =
      Enum.reduce(lines, {%__MODULE__{}, []}, &process_line/2)

    stripped =
      kept
      |> Enum.reverse()
      |> trim_blank_edges()
      |> Enum.join("\n")

    {meta, stripped}
  end

  defp process_line(line, {meta, keep}) do
    with :not_matched <- match_local(line, meta),
         :not_matched <- match_date(line, meta),
         :not_matched <- match_time(line, meta) do
      {meta, [line | keep]}
    else
      {:ok, updated_meta} -> {updated_meta, keep}
    end
  end

  defp match_local(line, %__MODULE__{local: nil} = meta) do
    case Regex.run(@local_line, line) do
      [_, value] -> {:ok, %{meta | local: String.trim(value)}}
      _ -> :not_matched
    end
  end

  defp match_local(_line, _meta), do: :not_matched

  defp match_date(line, %__MODULE__{date: nil} = meta) do
    with [_, d, m, y] <- Regex.run(@data_line, line),
         {:ok, date} <- parse_date(d, m, y) do
      {:ok, %{meta | date: date}}
    else
      _ -> :not_matched
    end
  end

  defp match_date(_line, _meta), do: :not_matched

  defp match_time(line, %__MODULE__{time: nil} = meta) do
    with [_, h, m] <- Regex.run(@hora_line, line),
         {:ok, time} <- parse_time(h, m) do
      {:ok, %{meta | time: time}}
    else
      _ -> :not_matched
    end
  end

  defp match_time(_line, _meta), do: :not_matched

  defp trim_blank_edges(lines) do
    lines
    |> Enum.drop_while(&(String.trim(&1) == ""))
    |> Enum.reverse()
    |> Enum.drop_while(&(String.trim(&1) == ""))
    |> Enum.reverse()
  end

  @doc "Serializes the meta struct into canonical text lines (no trailing newline)."
  @spec serialize(t()) :: String.t()
  def serialize(%__MODULE__{} = meta) do
    [
      meta.local && "Local: " <> meta.local,
      meta.date && "Data: " <> format_date_brief(meta.date),
      meta.time && "Horário: " <> format_time(meta.time) <> " (BRT)"
    ]
    |> Enum.reject(&(&1 in [nil, false]))
    |> Enum.join("\n")
  end

  @doc """
  Combines a meta struct with a free-form description into the full header
  that gets persisted to the markdown file.
  """
  @spec build_header(t(), String.t() | nil) :: String.t()
  def build_header(%__MODULE__{} = meta, description) do
    meta_text = serialize(meta)
    desc_text = (description || "") |> to_string() |> String.trim()

    case {meta_text, desc_text} do
      {"", d} -> d
      {m, ""} -> m
      {m, d} -> m <> "\n\n" <> d
    end
  end

  @doc "Builds a meta struct from raw string params (e.g. from form submissions)."
  @spec from_params(map()) :: t()
  def from_params(params) when is_map(params) do
    %__MODULE__{
      local: params |> get_string("local") |> presence(),
      date: params |> get_string("date") |> parse_date_input(),
      time: params |> get_string("time") |> parse_time_input()
    }
  end

  defp get_string(map, key), do: map |> Map.get(key, "") |> to_string()

  defp presence(""), do: nil

  defp presence(str) do
    case String.trim(str) do
      "" -> nil
      s -> s
    end
  end

  # HTML5 <input type="date"> gives YYYY-MM-DD
  defp parse_date_input(""), do: nil

  defp parse_date_input(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  # HTML5 <input type="time"> gives HH:MM (24h)
  defp parse_time_input(""), do: nil

  defp parse_time_input(str) do
    case Time.from_iso8601(str <> ":00") do
      {:ok, time} ->
        time

      _ ->
        case Time.from_iso8601(str) do
          {:ok, time} -> time
          _ -> nil
        end
    end
  end

  defp parse_date(d, m, y) do
    year =
      case String.length(y) do
        2 -> 2000 + String.to_integer(y)
        _ -> String.to_integer(y)
      end

    with {d, ""} <- Integer.parse(d),
         {m, ""} <- Integer.parse(m),
         {:ok, date} <- Date.new(year, m, d) do
      {:ok, date}
    else
      _ -> :error
    end
  end

  defp parse_time(h, m) do
    with {h, ""} <- Integer.parse(h),
         {m, ""} <- Integer.parse(m),
         {:ok, time} <- Time.new(h, m, 0) do
      {:ok, time}
    else
      _ -> :error
    end
  end

  # ---------- Display helpers ----------

  @doc "Formats a full date+time meta for the UI widget (pt-BR)."
  @spec format_when(t()) :: String.t()
  def format_when(%__MODULE__{date: nil, time: nil}), do: ""

  def format_when(%__MODULE__{date: date, time: nil}) do
    "#{format_weekday(date)}, #{format_date_long(date)}"
  end

  def format_when(%__MODULE__{date: nil, time: time}) do
    "#{format_time(time)} (BRT)"
  end

  def format_when(%__MODULE__{date: date, time: time}) do
    "#{format_weekday(date)}, #{format_date_long(date)} · #{format_time(time)} (BRT)"
  end

  @doc "Values pre-populated in the admin form."
  @spec to_form_params(t()) :: map()
  def to_form_params(%__MODULE__{} = meta) do
    %{
      "local" => meta.local || "",
      "date" => (meta.date && Date.to_iso8601(meta.date)) || "",
      "time" => (meta.time && Calendar.strftime(meta.time, "%H:%M")) || ""
    }
  end

  defp format_date_brief(%Date{} = d) do
    "#{pad2(d.day)}/#{pad2(d.month)}/#{d.year}"
  end

  defp format_date_long(%Date{} = d) do
    "#{d.day} de #{Enum.at(@months, d.month - 1)} de #{d.year}"
  end

  defp format_weekday(%Date{} = d) do
    idx = Date.day_of_week(d, :sunday) - 1
    Enum.at(@days, idx) |> String.capitalize()
  end

  defp format_time(%Time{} = t), do: "#{pad2(t.hour)}:#{pad2(t.minute)}"

  defp pad2(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  # ---------- Calendar exports ----------

  @doc "Timezone (IANA) used for events."
  def timezone, do: @tz

  @doc "Default duration in seconds used when only a start is known."
  def default_duration_seconds, do: @default_duration_seconds

  @doc """
  Returns a Google Calendar quick-add URL, or nil when the meta has no date.
  """
  @spec google_url(t(), String.t(), String.t()) :: String.t() | nil
  def google_url(%__MODULE__{date: nil}, _title, _event_url), do: nil

  def google_url(%__MODULE__{} = meta, title, event_url) do
    {start_str, end_str, all_day?} = google_dates(meta)

    params =
      [
        {"action", "TEMPLATE"},
        {"text", title},
        {"dates", "#{start_str}/#{end_str}"},
        {"location", meta.local || ""},
        {"details", "#{event_url}"}
      ]
      |> then(fn kv -> if all_day?, do: kv, else: kv ++ [{"ctz", @tz}] end)
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)

    "https://calendar.google.com/calendar/render?" <> URI.encode_query(params)
  end

  defp google_dates(%__MODULE__{date: date, time: nil}) do
    {basic_date(date), basic_date(Date.add(date, 1)), true}
  end

  defp google_dates(%__MODULE__{date: date, time: time}) do
    {end_date, end_time} = add_duration(date, time, @default_duration_seconds)

    {basic_datetime(date, time), basic_datetime(end_date, end_time), false}
  end

  @doc """
  Builds an RFC 5545 iCalendar payload (with CRLF line endings) for the event.
  Returns nil if no date is set.
  """
  @spec ics(t(), map()) :: String.t() | nil
  def ics(%__MODULE__{date: nil}, _), do: nil

  def ics(%__MODULE__{} = meta, %{title: title, slug: slug, url: url, description: description}) do
    now = DateTime.utc_now() |> Calendar.strftime("%Y%m%dT%H%M%SZ")

    {dtstart, dtend} = ics_times(meta)

    lines =
      [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Rolezinho//pt-BR",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        "BEGIN:VEVENT",
        "UID:#{slug}@rolezinho",
        "DTSTAMP:#{now}",
        dtstart,
        dtend,
        "SUMMARY:#{escape_ics(title)}",
        meta.local && "LOCATION:#{escape_ics(meta.local)}",
        "URL:#{url}",
        "DESCRIPTION:#{escape_ics(description || url)}",
        "END:VEVENT",
        "END:VCALENDAR"
      ]
      |> Enum.reject(&(&1 in [nil, false]))

    Enum.join(lines, "\r\n") <> "\r\n"
  end

  defp ics_times(%__MODULE__{date: date, time: nil}) do
    {
      "DTSTART;VALUE=DATE:#{basic_date(date)}",
      "DTEND;VALUE=DATE:#{basic_date(Date.add(date, 1))}"
    }
  end

  defp ics_times(%__MODULE__{date: date, time: time}) do
    start_utc = brt_to_utc(date, time)
    end_utc = brt_to_utc_add(date, time, @default_duration_seconds)

    {
      "DTSTART:#{utc_basic(start_utc)}",
      "DTEND:#{utc_basic(end_utc)}"
    }
  end

  # BRT is UTC-3 (no DST). Add 3h to get UTC.
  defp brt_to_utc(date, time) do
    NaiveDateTime.new!(date, time)
    |> NaiveDateTime.add(-@tz_offset_seconds, :second)
  end

  defp brt_to_utc_add(date, time, extra_seconds) do
    NaiveDateTime.new!(date, time)
    |> NaiveDateTime.add(-@tz_offset_seconds + extra_seconds, :second)
  end

  defp add_duration(date, time, extra_seconds) do
    ndt = NaiveDateTime.new!(date, time) |> NaiveDateTime.add(extra_seconds, :second)
    {NaiveDateTime.to_date(ndt), NaiveDateTime.to_time(ndt)}
  end

  defp basic_date(%Date{} = d), do: "#{d.year}#{pad2(d.month)}#{pad2(d.day)}"

  defp basic_datetime(%Date{} = d, %Time{} = t) do
    "#{basic_date(d)}T#{pad2(t.hour)}#{pad2(t.minute)}00"
  end

  defp utc_basic(%NaiveDateTime{} = ndt) do
    "#{basic_date(NaiveDateTime.to_date(ndt))}T#{pad2(ndt.hour)}#{pad2(ndt.minute)}#{pad2(ndt.second)}Z"
  end

  defp escape_ics(nil), do: ""

  defp escape_ics(str) do
    str
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace(",", "\\,")
    |> String.replace(";", "\\;")
    |> String.replace(~r/\r?\n/, "\\n")
  end
end

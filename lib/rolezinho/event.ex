defmodule Rolezinho.Event do
  @moduledoc """
  Represents a rolezinho (event), persisted as a row in the `events` table.

  The struct also provides pure functions to render/share the event as text
  and to manipulate the attendee lists. All mutation functions return a new
  `%Event{}` struct without touching the database — the `Rolezinho.Events`
  context is what persists changes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee

  @statuses [:active, :hidden, :done]

  @slug_regex ~r/^[a-z0-9](?:[a-z0-9-]{0,60}[a-z0-9])?$/

  schema "events" do
    field :slug, :string
    field :title, :string, default: ""
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :header, :string, default: ""
    field :footer, :string, default: ""
    field :main_capacity, :integer, default: 0
    field :wait_enabled, :boolean, default: false
    field :wait_intro, :string, default: "Lista de reserva"

    embeds_many :main_list, Attendee, on_replace: :delete
    embeds_many :wait_list, Attendee, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @type status :: :active | :hidden | :done

  @type t :: %__MODULE__{
          id: integer() | nil,
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

  @doc """
  Full changeset used by the `Rolezinho.Events` context to persist events.
  Callers pass a plain map of attributes; embeds are cast recursively.
  """
  def changeset(%Event{} = event, attrs) do
    event
    |> cast(attrs, [
      :slug,
      :title,
      :status,
      :header,
      :footer,
      :main_capacity,
      :wait_enabled,
      :wait_intro
    ])
    |> cast_embed(:main_list, with: &Attendee.changeset/2)
    |> cast_embed(:wait_list, with: &Attendee.changeset/2)
    |> validate_required([:slug, :title, :status])
    |> update_change(:slug, &String.downcase(String.trim(&1 || "")))
    |> validate_format(:slug, @slug_regex, message: "use letras minúsculas, números e traços")
    |> validate_number(:main_capacity, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug, message: "já está em uso")
  end

  @doc "Valid values for the `status` enum."
  def statuses, do: @statuses

  @doc "Regex used to validate slug values."
  def slug_regex, do: @slug_regex

  # ---------- Text renderers ----------

  @doc """
  Serializes an %Event{} into the pretty markdown form that used to live on disk.
  Still used as the initial value for the raw editor and for exports.
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

  # ---------- Pure list operations ----------

  @doc "Ensures the main list has exactly `capacity` slots (padding with empty)."
  @spec normalize_main(t()) :: t()
  def normalize_main(%Event{} = event) do
    filled = compact_main(event.main_list)
    capacity = max(event.main_capacity, length(filled))
    padded = pad(filled, capacity)
    %{event | main_capacity: capacity, main_list: padded}
  end

  @doc "Adds an attendee to the first empty main slot."
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
        {:ok, %{event | main_list: list}}
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
        {:ok, %{event | wait_list: event.wait_list ++ [%Attendee{name: name, paid: false}]}}
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

    %{event | main_list: compact_then_pad(new_list, event.main_capacity)}
  end

  @doc "Removes an attendee from the wait list (1-based)."
  @spec remove_wait(t(), pos_integer()) :: t()
  def remove_wait(%Event{} = event, index) do
    %{event | wait_list: List.delete_at(event.wait_list, index - 1)}
  end

  @doc "Toggles the paid flag on a main list attendee (1-based)."
  @spec toggle_paid_main(t(), pos_integer()) :: t()
  def toggle_paid_main(%Event{} = event, index) do
    list = update_at(event.main_list, index - 1, fn att -> %{att | paid: !att.paid} end)
    %{event | main_list: list}
  end

  @doc "Toggles the paid flag on a wait list attendee."
  @spec toggle_paid_wait(t(), pos_integer()) :: t()
  def toggle_paid_wait(%Event{} = event, index) do
    list = update_at(event.wait_list, index - 1, fn att -> %{att | paid: !att.paid} end)
    %{event | wait_list: list}
  end

  @doc "Renames a main list attendee."
  @spec rename_main(t(), pos_integer(), String.t()) :: t()
  def rename_main(%Event{} = event, index, name) do
    name = clean_name(name)
    list = update_at(event.main_list, index - 1, fn att -> %{att | name: name} end)
    %{event | main_list: list}
  end

  @doc "Renames a wait list attendee."
  @spec rename_wait(t(), pos_integer(), String.t()) :: t()
  def rename_wait(%Event{} = event, index, name) do
    name = clean_name(name)
    list = update_at(event.wait_list, index - 1, fn att -> %{att | name: name} end)
    %{event | wait_list: list}
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
        {:ok, %{event | main_list: new_main, wait_list: new_wait}}
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
    %{event | main_capacity: new_capacity, main_list: pad(filled, new_capacity)}
  end

  @doc "How many main slots are still empty."
  @spec main_free_slots(t()) :: non_neg_integer()
  def main_free_slots(%Event{} = event) do
    event.main_capacity - length(compact_main(event.main_list))
  end

  @doc "True when the main list has no empty slots."
  @spec main_full?(t()) :: boolean()
  def main_full?(%Event{} = event), do: main_free_slots(event) <= 0

  # ---------- Serialization helpers ----------

  @doc """
  Converts the attendee lists in an event struct into plain maps, suitable for
  passing back into `changeset/2` as attrs.
  """
  @spec attrs_from_struct(t()) :: map()
  def attrs_from_struct(%Event{} = event) do
    %{
      slug: event.slug,
      title: event.title,
      status: event.status,
      header: event.header,
      footer: event.footer,
      main_capacity: event.main_capacity,
      wait_enabled: event.wait_enabled,
      wait_intro: event.wait_intro,
      main_list: Enum.map(event.main_list, &attendee_to_map/1),
      wait_list: Enum.map(event.wait_list, &attendee_to_map/1)
    }
  end

  defp attendee_to_map(%Attendee{name: n, paid: p}), do: %{name: n, paid: p}

  # ---------- Rendering helpers ----------

  defp render_list(list, capacity) do
    slots = pad(compact_main(list), capacity)

    slots
    |> Enum.with_index(1)
    |> Enum.map(fn {%Attendee{} = att, i} -> render_attendee_line(i, att) end)
    |> Enum.join("\n")
  end

  defp render_wait_list([]), do: "1-"

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

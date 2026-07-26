defmodule Rolezinho.Event.FormField do
  @moduledoc """
  A question the organizer asks whoever joins. Embedded in `Rolezinho.Event`.

  The default form is a single field — the name — because every extra field is
  something between a person and the list (RN-61). Adding one is an explicit
  choice with a cost, not a default.

  Name is locked (RN-60): it identifies the row, so removing it would leave the
  list with nothing to display, and making it optional would allow blank rows.

  Answers live on the attendee and belong to that event alone (RN-62). They are
  visible to the organizer and never rendered in the public list — a shirt size
  is between the two of them, not something the group reads.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Rolezinho.Event.FormField

  @types ~w(text tel number)

  @primary_key false
  embedded_schema do
    field :id, :string
    field :label, :string
    field :placeholder, :string
    field :type, :string, default: "text"
    field :required, :boolean, default: false
    field :locked, :boolean, default: false
  end

  @type t :: %__MODULE__{
          id: String.t() | nil,
          label: String.t() | nil,
          placeholder: String.t() | nil,
          type: String.t(),
          required: boolean(),
          locked: boolean()
        }

  @doc "Valid input types for a custom field."
  def types, do: @types

  def changeset(field, params \\ %{}) do
    field
    |> cast(params, [:id, :label, :placeholder, :type, :required, :locked])
    |> validate_required([:id, :label])
    |> validate_inclusion(:type, @types)
    |> validate_length(:label, min: 1, max: 40)
    |> validate_length(:placeholder, max: 60)
  end

  @doc """
  The form an event has when the organizer has not configured one (RN-61).

  Just the name, locked and required. Anything more is a decision somebody has
  to make on purpose.

  ## Examples

      iex> [%Rolezinho.Event.FormField{id: "name"}] = Rolezinho.Event.FormField.default()
  """
  @spec default() :: [t()]
  def default do
    [
      %FormField{
        id: "name",
        label: "Nome",
        placeholder: "Como te chamam no grupo",
        type: "text",
        required: true,
        locked: true
      }
    ]
  end

  @doc """
  The fields an event actually asks for, falling back to the default.

  An event created before custom forms existed has none stored, and reads as
  the default rather than as a form with no fields at all.
  """
  @spec for_event([t()] | nil) :: [t()]
  def for_event(nil), do: default()
  def for_event([]), do: default()

  def for_event(fields) do
    # The name is what identifies a row, so it is always asked even if a stored
    # form somehow lost it.
    if Enum.any?(fields, &(&1.id == "name")), do: fields, else: default() ++ fields
  end

  @doc """
  Builds an id from a label, unique against the ids already in use.

  Ids end up as form field names and map keys, so they stay in the safe subset
  regardless of what was typed as a label.

  ## Examples

      iex> Rolezinho.Event.FormField.build_id("Camisa (P/M/G)", [])
      "camisa-p-m-g"
  """
  @spec build_id(String.t(), [String.t()]) :: String.t()
  def build_id(label, taken) do
    base =
      label
      |> String.downcase()
      |> :unicode.characters_to_nfd_binary()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")
      |> String.slice(0, 30)

    base = if base == "", do: "campo", else: base

    if base in taken, do: unique(base, taken, 2), else: base
  end

  defp unique(base, taken, suffix) do
    candidate = "#{base}-#{suffix}"
    if candidate in taken, do: unique(base, taken, suffix + 1), else: candidate
  end
end

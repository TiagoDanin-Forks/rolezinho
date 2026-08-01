defmodule Rolezinho.Event.Attendee do
  @moduledoc """
  A single spot in a list (may be empty). Embedded in `Rolezinho.Event`.

  `participant_id` is what makes "only you mark your own Pix" enforceable: the
  browser holds the same opaque id in a signed cookie and the server compares
  the two. It identifies a device, not a person — there are no accounts — so
  clearing cookies means losing the claim to the row.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :name, :string, default: ""
    field :paid, :boolean, default: false

    field :participant_id, :string
    field :joined_at, :utc_datetime

    # Answers to the organizer's custom fields. Scoped to the event and visible
    # to the organizer — never rendered in the public list.
    field :values, :map, default: %{}
  end

  @type t :: %__MODULE__{
          name: String.t(),
          paid: boolean(),
          participant_id: String.t() | nil,
          joined_at: DateTime.t() | nil,
          values: map()
        }

  def changeset(attendee, params \\ %{}) do
    attendee
    |> cast(params, [:name, :paid, :participant_id, :joined_at, :values])
    |> validate_length(:name, max: 60)
  end

  @doc """
  Returns true when this spot belongs to the given participant.

  A blank id never matches: an empty slot, or a row created before identity
  existed, must not be claimable by a browser that happens to send nothing.
  """
  @spec owned_by?(t(), String.t() | nil) :: boolean()
  def owned_by?(%__MODULE__{participant_id: id}, participant_id)
      when is_binary(id) and is_binary(participant_id) and id != "" and participant_id != "" do
    Plug.Crypto.secure_compare(id, participant_id)
  end

  def owned_by?(%__MODULE__{}, _), do: false
end

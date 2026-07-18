defmodule Rolezinho.Event.Attendee do
  @moduledoc "A single spot in a list (may be empty). Embedded in `Rolezinho.Event`."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :name, :string, default: ""
    field :paid, :boolean, default: false
  end

  @type t :: %__MODULE__{name: String.t(), paid: boolean()}

  def changeset(attendee, params \\ %{}) do
    cast(attendee, params, [:name, :paid])
  end
end

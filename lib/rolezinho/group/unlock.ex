defmodule Rolezinho.Group.Unlock do
  @moduledoc """
  A signed-in user's persisted unlock of a password-protected group.

  Once the user has entered the group's password correctly, this row lets
  the same GitHub account unlock the group from any device without typing
  it again. Group unlock in the session (`:unlocked_groups`) still exists
  for anonymous visitors; a signed-in user gets the session unlock too,
  plus this durable record.

  See ADR-0002 for the accounts model and SECURITY.md §3 for the group
  password model this rides on.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Rolezinho.Accounts.User
  alias Rolezinho.Group

  schema "group_unlocks" do
    belongs_to :user, User
    belongs_to :group, Group

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          group_id: integer() | nil
        }

  @doc false
  def changeset(unlock, attrs) do
    unlock
    |> cast(attrs, [:user_id, :group_id])
    |> validate_required([:user_id, :group_id])
    |> unique_constraint([:user_id, :group_id])
  end
end

defmodule Rolezinho.Accounts.PasswordResetToken do
  @moduledoc """
  A single-use, expiring credential that lets the holder replace the
  password of a specific user without knowing the current one.

  Storage is the SHA-256 of the plaintext token (see the migration for
  why). The plaintext is only ever handed to the user — as the trailing
  path segment of the reset link we email to them — and is not
  recoverable from the DB. Redemption hashes what the URL supplied and
  looks up by that hash.

  A row is:

    * fresh when `used_at` is nil and `expires_at` is in the future,
    * consumed when `used_at` is set (the redemption path stamps it in
      the same transaction that updates the password),
    * expired when `expires_at` is in the past — the sweep on the next
      request from the same user deletes it, but the redeem path also
      rejects it defensively.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Rolezinho.Accounts.User

  schema "password_reset_tokens" do
    field :token_hash, :binary
    field :sent_to_email, :string
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime

    belongs_to :user, User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @type t :: %__MODULE__{
          id: integer() | nil,
          token_hash: binary() | nil,
          sent_to_email: String.t() | nil,
          expires_at: DateTime.t() | nil,
          used_at: DateTime.t() | nil,
          user_id: integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t()
        }

  @doc """
  Changeset used at insert time.

  `:user_id`, `:token_hash`, `:sent_to_email`, and `:expires_at` are
  set by the context (`Accounts.request_password_reset/1`), never by
  user input — so this is a private helper, not a form-facing
  changeset.
  """
  def new_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:user_id, :token_hash, :sent_to_email, :expires_at])
    |> validate_required([:user_id, :token_hash, :sent_to_email, :expires_at])
  end
end

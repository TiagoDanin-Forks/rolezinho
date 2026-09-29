defmodule Rolezinho.Repo.Migrations.AddPasswordResetTokens do
  use Ecto.Migration

  @moduledoc """
  Password-reset tokens for the local-auth path (2026-09 amendment to
  ADR-0002).

  What's stored is the SHA-256 hash of the token, not the token itself,
  so a stolen DB dump does not translate to instant reset ability for
  the attacker. The plaintext token only ever exists in the reset link
  we email to the user; the DB round-trip runs `:crypto.hash(:sha256, _)`
  on the way in and compares hashes.

  `sent_to_email` records the address the link was mailed to at request
  time, so a later email-field edit does not muddy an audit trail. A
  reset link mailed to an address the user later removes is still
  redeemable — but only via the mailbox that originally received it.

  Tokens expire in 1 hour (enforced by the context, not the DB), and
  are single-use (`used_at` set at redemption; subsequent redeem
  attempts on the same row fail).
  """

  def change do
    create table(:password_reset_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token_hash, :binary, null: false
      add :sent_to_email, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Unique so a token is redeemable by exactly one row. Also serves as
    # the lookup index for the redeem path.
    create unique_index(:password_reset_tokens, [:token_hash])

    # Enables the "invalidate prior tokens for this user" sweep the
    # context runs before inserting a fresh one.
    create index(:password_reset_tokens, [:user_id])
  end
end

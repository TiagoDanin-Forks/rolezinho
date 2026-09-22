defmodule Rolezinho.Repo.Migrations.SplitHiddenFromStatus do
  use Ecto.Migration

  @moduledoc """
  Splits "occult" (hidden from the public home) out of the status enum
  and into its own boolean column, so a rolê can be, say, `payments_only`
  AND hidden at the same time \u2014 states that were mutually exclusive under
  the old `status = :hidden` encoding.

  Backfill: every row currently at `status = 'hidden'` gets `hidden = true`
  and its status flipped to `active`, which was the intent of "hidden"
  before the split (an active rolê that just isn't listed on the home).
  """

  def up do
    alter table(:events) do
      add :hidden, :boolean, null: false, default: false
    end

    # Backfill. `execute/1` runs raw SQL against the DB the migration owns.
    execute("UPDATE events SET status = 'active', hidden = true WHERE status = 'hidden'")

    # The status index still points at values that now exclude 'hidden'.
    # Add a partial index on `hidden` to keep list_hidden/0 cheap once the
    # column is well-populated.
    create index(:events, [:hidden], where: "hidden = true", name: :events_hidden_index)
  end

  def down do
    drop index(:events, [:hidden], name: :events_hidden_index)

    execute("UPDATE events SET status = 'hidden' WHERE hidden = true")

    alter table(:events) do
      remove :hidden
    end
  end
end

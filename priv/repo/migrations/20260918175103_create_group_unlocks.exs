defmodule Rolezinho.Repo.Migrations.CreateGroupUnlocks do
  @moduledoc """
  Persists a signed-in user's successful unlock of a password-protected
  group so they do not need to type the password again on the next visit
  or on another device.

  The tuple `(user_id, group_id)` is what matters; there is nothing else to
  store beyond an audit timestamp. Both foreign keys cascade delete: when
  a user is deleted their unlocks vanish, and when a group is deleted so
  do the unlocks pointing at it.
  """
  use Ecto.Migration

  def change do
    create table(:group_unlocks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :group_id, references(:groups, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # One row per (user, group) — re-unlocking is idempotent, not additive.
    create unique_index(:group_unlocks, [:user_id, :group_id])
    # Group-side lookups are rare; user-side "which groups have I unlocked?"
    # runs on every request that touches a group, so it gets its own index.
    create index(:group_unlocks, [:user_id])
  end
end

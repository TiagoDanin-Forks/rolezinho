defmodule Rolezinho.Repo.Migrations.AddLocalAuthToUsers do
  use Ecto.Migration

  @moduledoc """
  Adds the local (username + password) auth path alongside GitHub OAuth
  (ADR-0002 amendment).

  Adds two columns:

    * `username` — the login identifier for the local path AND the
      canonical handle for every user (GitHub users get one auto-
      derived from `github_login` at signup; see the schema). Stored
      lowercase, unique across all users.

    * `password_hash` — bcrypt hash. Nullable because GitHub-only
      users won't have one until they set a password from `/me`.

  Backfill: every existing user (all GitHub-authed today) gets
  `username = lower(github_login)`. Verified in prod there are no
  collisions on `lower(github_login)` before shipping this.
  """

  def up do
    alter table(:users) do
      add :username, :string
      add :password_hash, :string
      # `github_id` was NOT NULL under ADR-0002's single-provider
      # assumption. Local-auth users don't have one, so relax it.
      # The unique index on `github_id` stays and still enforces
      # uniqueness among rows that DO have one.
      modify :github_id, :bigint, null: true, from: {:bigint, null: false}
      modify :github_login, :string, null: true, from: {:string, null: false}
    end

    execute("UPDATE users SET username = lower(github_login) WHERE username IS NULL")

    # `NOT NULL` and the unique index on username only after backfill,
    # so an empty username never blocks the migration.
    alter table(:users) do
      modify :username, :string, null: false
    end

    create unique_index(:users, [:username])
  end

  def down do
    drop index(:users, [:username])

    alter table(:users) do
      remove :username
      remove :password_hash
      modify :github_id, :bigint, null: false, from: {:bigint, null: true}
      modify :github_login, :string, null: false, from: {:string, null: true}
    end
  end
end

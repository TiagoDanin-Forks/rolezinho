defmodule Rolezinho.Repo.Migrations.CreateUsers do
  @moduledoc """
  Introduces user accounts, backed by GitHub OAuth, per ADR-0002.

  The identity pin is `github_id` — GitHub's numeric user id, which never
  changes. `github_login` is the current username and is refreshed on every
  sign-in; `name`, `email`, `avatar_url` are cached from the OAuth response
  and treated as untrusted display strings. Every string column is
  length-bounded because GitHub does not validate these for us.

  `events.created_by_user_id` and `groups.created_by_user_id` are the new
  ownership pointers. Both are nullable so pre-existing rows (created before
  this migration ran) carry `NULL` and stay reachable via the bearer-secret
  identities they already had. `on_delete: :nilify_all` — deleting a user
  cannot silently take their events with them; the events survive, losing
  their creator link and dropping back to token-only administration.
  """
  use Ecto.Migration

  def change do
    create table(:users) do
      # Numeric GitHub id: never changes across renames or transfers.
      add :github_id, :bigint, null: false
      add :github_login, :string, null: false, size: 80
      add :name, :string, size: 120
      add :email, :string, size: 200
      add :avatar_url, :string, size: 400

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:github_id])
    # `github_login` is not unique in the DB, because two users on GitHub can
    # end up with the same historical login value (renames, deletions). We
    # sort them out by numeric id.
    create index(:users, [:github_login])

    alter table(:events) do
      add :created_by_user_id, references(:users, on_delete: :nilify_all)
    end

    alter table(:groups) do
      add :created_by_user_id, references(:users, on_delete: :nilify_all)
    end

    # Owner listings walk both directions of this join often enough to earn
    # its own index.
    create index(:events, [:created_by_user_id])
    create index(:groups, [:created_by_user_id])
  end
end

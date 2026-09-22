defmodule Rolezinho.Repo.Migrations.AddAdminToUsers do
  use Ecto.Migration

  def change do
    # Admin capability tied to the user account (ADR-0002). Complements the
    # environment-wide `ADMIN_PASSWORD` bypass: a signed-in user whose row
    # is flagged `admin: true` gets the same rights, on every device they
    # sign in from, without ever touching the shared password.
    alter table(:users) do
      add :admin, :boolean, null: false, default: false
    end
  end
end

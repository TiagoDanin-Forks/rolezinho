defmodule Rolezinho.Repo.Migrations.AddPasswordToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :password, :text
    end
  end
end

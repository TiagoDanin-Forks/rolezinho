defmodule Rolezinho.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :slug, :string, null: false, size: 80
      add :title, :string, null: false, default: ""
      add :status, :string, null: false, default: "active"
      add :header, :text, null: false, default: ""
      add :footer, :text, null: false, default: ""
      add :main_capacity, :integer, null: false, default: 0
      add :wait_enabled, :boolean, null: false, default: true
      add :wait_intro, :string, null: false, default: "Lista de reserva"
      add :main_list, {:array, :map}, null: false, default: []
      add :wait_list, {:array, :map}, null: false, default: []

      timestamps(type: :utc_datetime)
    end

    create unique_index(:events, [:slug])
    create index(:events, [:status])
  end
end

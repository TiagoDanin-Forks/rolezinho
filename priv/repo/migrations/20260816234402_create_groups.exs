defmodule Rolezinho.Repo.Migrations.CreateGroups do
  @moduledoc """
  Groups: a bundle of events that share a page at `/g/:slug`.

  Groups live alongside events, not above them. An event can belong to at most
  one group and joining or leaving one is purely reference — the events are the
  authoritative rows, deleting a group must never take an event with it. That is
  what `on_delete: :nilify_all` says: the events survive; they simply lose their
  home.

  A group's password mirrors the event password (SECURITY.md §3): plaintext by
  deliberate decision, because it is shared in the same message that carries the
  link and must be readable back. It is friction, not secrecy.
  """
  use Ecto.Migration

  def change do
    create table(:groups) do
      add :slug, :string, null: false, size: 80
      add :name, :string, null: false, default: ""
      add :password, :string
      add :visibility, :string, null: false, default: "public"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:groups, [:slug])
    create index(:groups, [:visibility])

    alter table(:events) do
      add :group_id, references(:groups, on_delete: :nilify_all)
    end

    # The home listing filters events out of the top level when they belong to
    # a group, and the group page walks the other way — both queries touch this
    # column often enough to be worth indexing.
    create index(:events, [:group_id])
  end
end

defmodule Rolezinho.Repo.Migrations.AddStructuredFieldsToEvents do
  @moduledoc """
  Replaces the free-text description with real fields.

  Location, date, time, price and the Pix key used to live inside the markdown
  header and were recovered with regexes. As columns they can be validated,
  sorted and rendered into the `.ics` without parsing prose. `header`/`footer`
  stay for now: the current screens still render them, and they only go once the
  v2 screens replace them.

  `organizer_token` is what turns "one event, one organizer" into something the
  server can check — whoever creates the event holds the secret, instead of a
  single environment-wide admin password standing in for every organizer.
  """
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :category, :string, size: 40
      add :local, :string, size: 200
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :price_cents, :integer
      add :pix_key, :string, size: 100
      add :organizer_token, :string, size: 64
    end

    # Looking an event up by the organizer's secret has to be as cheap as looking
    # it up by slug: it happens on every admin request for that event.
    create unique_index(:events, [:organizer_token])
    # The home listing orders by start time.
    create index(:events, [:starts_at])
  end
end

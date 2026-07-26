defmodule Rolezinho.Repo.Migrations.AddFormFieldsToEvents do
  @moduledoc """
  Lets the organizer decide what the join form asks (RN-60, RN-61).

  Null rather than an empty array as the default: an event that has never
  configured a form is not the same as one configured to ask nothing, and only
  the first should fall back to asking for a name.
  """
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :form_fields, {:array, :map}
    end
  end
end

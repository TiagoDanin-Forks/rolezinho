defmodule Rolezinho.Repo.Migrations.AddPixKeyTypeToEvents do
  use Ecto.Migration

  @moduledoc """
  Adds an explicit `pix_key_type` column so the organizer chooses which of the
  five DICT key types their key is, instead of the app guessing from the
  string's shape.

  Guessing had a well-known bug: an 11-digit bare number is both a valid
  mobile-phone Pix and a valid CPF, and the guesser defaulted to CPF (the
  safer wrong answer), which produced a QR code that scanned and failed. With
  the type stated, the ambiguity disappears.

  Nullable so existing rows keep working: the runtime falls back to
  `Rolezinho.Pix.classify/1` for events created before the split. New writes
  require the type when a key is present (validated at the context layer).
  """

  def change do
    alter table(:events) do
      add :pix_key_type, :string
    end
  end
end

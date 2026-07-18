defmodule Mix.Tasks.Rolezinho.Import do
  @shortdoc "Imports rolezinho markdown files from DATA_PATH into the database"

  @moduledoc """
  Imports existing rolezinho markdown files into the Postgres database.

  Layout expected under `DATA_PATH` (defaults to `priv/data`, override with
  `--data-path` or the `DATA_PATH` environment variable):

      DATA_PATH/<slug>.md        -> imported with status :active
      DATA_PATH/hidden/<slug>.md -> imported with status :hidden
      DATA_PATH/done/<slug>.md   -> imported with status :done

  ## Options

      --data-path PATH   Override the base directory (defaults to config).
      --overwrite        Replace existing rows with the same slug.
      --dry-run          Parse files but don't touch the database.

  ## Examples

      mix rolezinho.import
      mix rolezinho.import --data-path /var/lib/rolezinho
      mix rolezinho.import --overwrite
      mix rolezinho.import --dry-run

  In a compiled release, use the equivalent `bin/import` binary instead.
  """

  use Mix.Task

  @impl true
  def run(argv) do
    {opts, _rest} =
      OptionParser.parse!(argv,
        strict: [data_path: :string, overwrite: :boolean, dry_run: :boolean]
      )

    Mix.Task.run("app.start")

    data_path =
      opts[:data_path] || System.get_env("DATA_PATH") ||
        Application.get_env(:rolezinho, :data_path, "priv/data")

    case Rolezinho.Importer.run(
           data_path: data_path,
           overwrite: Keyword.get(opts, :overwrite, false),
           dry_run: Keyword.get(opts, :dry_run, false),
           reporter: fn line -> Mix.shell().info(line) end
         ) do
      {:ok, _counts} -> :ok
      {:error, {:missing_data_path, path}} -> Mix.raise("Diretório #{path} não existe.")
      {:error, reason} -> Mix.raise("Falha ao importar: #{inspect(reason)}")
    end
  end
end

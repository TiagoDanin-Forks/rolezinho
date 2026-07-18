defmodule Rolezinho.Release do
  @moduledoc """
  Entrypoints for running one-off commands inside a compiled release
  (`_build/prod/rel/rolezinho/bin/rolezinho eval "Rolezinho.Release.<fun>()"`).

  Mix is not available in a release, so these functions load the app manually
  and start `Rolezinho.Repo` for the duration of the operation.
  """

  @app :rolezinho

  @doc "Runs any pending Ecto migrations."
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc "Rolls back the given `repo` to `version`."
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Imports rolezinho markdown files into the database. Options are read from
  environment variables so the `bin/import` shell wrapper can drive it:

    * `DATA_PATH`        — required; base directory containing the `.md` files.
    * `IMPORT_OVERWRITE` — `"true"` to replace existing rows with the same slug.
    * `IMPORT_DRY_RUN`   — `"true"` to parse files without touching the database.
  """
  def import do
    load_app()

    data_path = System.get_env("DATA_PATH") || raise "DATA_PATH env var is required"
    overwrite? = System.get_env("IMPORT_OVERWRITE") == "true"
    dry_run? = System.get_env("IMPORT_DRY_RUN") == "true"

    for repo <- repos() do
      {:ok, result, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          Rolezinho.Importer.run(
            data_path: data_path,
            overwrite: overwrite?,
            dry_run: dry_run?,
            reporter: &IO.puts/1
          )
        end)

      case result do
        {:ok, _counts} ->
          :ok

        {:error, {:missing_data_path, path}} ->
          IO.puts(:stderr, "Diretório #{path} não existe.")
          System.halt(1)

        {:error, reason} ->
          IO.puts(:stderr, "Falha ao importar: #{inspect(reason)}")
          System.halt(1)
      end
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end

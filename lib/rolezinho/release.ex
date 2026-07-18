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

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end

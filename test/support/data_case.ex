defmodule Rolezinho.DataCase do
  @moduledoc """
  Test helpers for tests that interact with the database via Ecto.

  Uses the SQL sandbox so tests are isolated and can run concurrently.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Rolezinho.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Rolezinho.DataCase
    end
  end

  setup tags do
    Rolezinho.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc "Sets up the Ecto SQL sandbox based on the test tags."
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Rolezinho.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc "Traverses changeset errors into a map of messages for assertions."
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

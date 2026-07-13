defmodule Rolezinho.DataCase do
  @moduledoc """
  Test helpers for tests that interact with the file-based storage.

  Configures an isolated `DATA_PATH` per test and cleans it up on exit.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Rolezinho.DataCase
    end
  end

  setup tags do
    Rolezinho.DataCase.setup_data_dir(tags)
    :ok
  end

  @doc """
  Points `:rolezinho, :data_path` at a fresh directory for the duration of the test.
  """
  def setup_data_dir(_tags) do
    dir = Path.join([System.tmp_dir!(), "rolezinho_test", random_id()])
    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    File.mkdir_p!(Path.join(dir, "hidden"))
    File.mkdir_p!(Path.join(dir, "done"))

    prev = Application.get_env(:rolezinho, :data_path)
    Application.put_env(:rolezinho, :data_path, dir)

    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf!(dir)
      Application.put_env(:rolezinho, :data_path, prev)
    end)

    {:ok, data_path: dir}
  end

  defp random_id do
    :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower)
  end
end

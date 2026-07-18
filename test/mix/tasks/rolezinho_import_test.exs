defmodule Mix.Tasks.Rolezinho.ImportTest do
  use Rolezinho.DataCase, async: false

  alias Rolezinho.Event
  alias Rolezinho.Events

  setup do
    dir =
      Path.join(System.tmp_dir!(), "rolezinho_import_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(dir, "hidden"))
    File.mkdir_p!(Path.join(dir, "done"))

    on_exit(fn -> File.rm_rf!(dir) end)

    %{dir: dir}
  end

  defp write!(dir, path, contents), do: File.write!(Path.join(dir, path), contents)

  test "imports files with the correct status per directory", %{dir: dir} do
    write!(dir, "ativo.md", """
    # Ativo

    Local: Praia
    Data: 15/07/2026
    Horário: 19:00 (BRT)

    Valor: 15

    1- Alice ✅
    2- Bob
    3-

    Lista de reserva
    1- Charlie
    """)

    write!(dir, "hidden/oculto.md", """
    # Oculto

    1-
    2-
    """)

    write!(dir, "done/concluido.md", """
    # Concluído

    1- X
    2- Y
    """)

    Mix.Task.rerun("rolezinho.import", ["--data-path", dir])

    ativo = Events.find("ativo")
    assert ativo.status == :active
    assert ativo.title == "Ativo"
    assert ativo.main_capacity == 3
    assert Enum.at(ativo.main_list, 0).name == "Alice"
    assert Enum.at(ativo.main_list, 0).paid == true
    assert length(ativo.wait_list) == 1
    assert Enum.at(ativo.wait_list, 0).name == "Charlie"
    # Header preserved for the widget
    assert ativo.header =~ "Local: Praia"
    assert ativo.header =~ "Valor: 15"

    assert Events.find("oculto").status == :hidden
    assert Events.find("concluido").status == :done
  end

  test "skips existing slugs by default, overwrites with --overwrite", %{dir: dir} do
    write!(dir, "reimport.md", "# V1\n\n1-\n2-\n")

    Mix.Task.rerun("rolezinho.import", ["--data-path", dir])
    assert Events.find("reimport").title == "V1"

    # Rewrite the source, run again -> skipped
    write!(dir, "reimport.md", "# V2\n\n1-\n2-\n")
    Mix.Task.rerun("rolezinho.import", ["--data-path", dir])
    assert Events.find("reimport").title == "V1"

    # With --overwrite the row is replaced
    Mix.Task.rerun("rolezinho.import", ["--data-path", dir, "--overwrite"])
    assert Events.find("reimport").title == "V2"
  end

  test "--dry-run parses but does not touch the DB", %{dir: dir} do
    write!(dir, "seco.md", "# Seco\n\n1- Somebody\n2-\n")

    Mix.Task.rerun("rolezinho.import", ["--data-path", dir, "--dry-run"])

    refute Events.find("seco")
    refute Repo.get_by(Event, slug: "seco")
  end
end

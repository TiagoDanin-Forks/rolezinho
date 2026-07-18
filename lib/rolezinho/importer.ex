defmodule Rolezinho.Importer do
  @moduledoc """
  Reusable, Mix-free implementation of the rolezinho markdown importer.

  Used by both the `mix rolezinho.import` task (in dev) and by
  `Rolezinho.Release.import/0` (in production release binaries).

  ## Options

  * `:data_path` — base directory containing `.md` files. Required.
  * `:overwrite` — replace existing rows with the same slug (default: `false`).
  * `:dry_run` — parse files but do not touch the database (default: `false`).
  * `:reporter` — 1-arity fn used to print progress lines (default: `&IO.puts/1`).

  Returns `{:ok, counts}` on success, `{:error, reason}` when the base directory
  is missing. `counts` is `%{ok: non_neg_integer, skipped: non_neg_integer, error: non_neg_integer}`.
  """

  alias Rolezinho.Event
  alias Rolezinho.Event.Parser
  alias Rolezinho.Events
  alias Rolezinho.Repo

  @statuses [:active, :hidden, :done]

  @type opts :: [
          data_path: String.t(),
          overwrite: boolean(),
          dry_run: boolean(),
          reporter: (String.t() -> any())
        ]

  @spec run(opts()) ::
          {:ok, %{ok: non_neg_integer(), skipped: non_neg_integer(), error: non_neg_integer()}}
          | {:error, term()}
  def run(opts) do
    base = Keyword.fetch!(opts, :data_path) |> Path.expand()
    reporter = Keyword.get(opts, :reporter, &IO.puts/1)
    overwrite? = Keyword.get(opts, :overwrite, false)
    dry_run? = Keyword.get(opts, :dry_run, false)

    reporter.("Importando rolezinhos de #{base}")

    cond do
      not File.dir?(base) ->
        {:error, {:missing_data_path, base}}

      true ->
        files = collect_files(base)

        if files == [] do
          reporter.("Nenhum arquivo .md encontrado.")
          {:ok, %{ok: 0, skipped: 0, error: 0}}
        else
          counts =
            Enum.reduce(files, %{ok: 0, skipped: 0, error: 0}, fn {slug, status, path}, acc ->
              import_one(slug, status, path, overwrite?, dry_run?, reporter, acc)
            end)

          reporter.(
            "Concluído: #{counts.ok} importados, #{counts.skipped} pulados, #{counts.error} com erro."
          )

          {:ok, counts}
        end
    end
  end

  defp collect_files(base) do
    Enum.flat_map(@statuses, fn status ->
      dir =
        case status do
          :active -> base
          :hidden -> Path.join(base, "hidden")
          :done -> Path.join(base, "done")
        end

      case File.ls(dir) do
        {:ok, entries} ->
          entries
          |> Enum.filter(&String.ends_with?(&1, ".md"))
          |> Enum.map(fn file ->
            slug = String.trim_trailing(file, ".md")
            {slug, status, Path.join(dir, file)}
          end)

        {:error, _} ->
          []
      end
    end)
  end

  defp import_one(slug, status, path, overwrite?, dry_run?, reporter, counts) do
    case File.read(path) do
      {:ok, content} ->
        parsed = Parser.parse(content)

        cond do
          dry_run? ->
            reporter.(
              "  [dry-run] #{status} #{slug} — título=\"#{parsed.title}\", " <>
                "capacidade=#{parsed.main_capacity}, " <>
                "principais=#{count_filled(parsed.main_list)}, " <>
                "reserva=#{length(parsed.wait_list)}"
            )

            %{counts | ok: counts.ok + 1}

          existing = Repo.get_by(Event, slug: slug) ->
            handle_existing(existing, slug, status, parsed, overwrite?, reporter, counts)

          true ->
            insert_new(slug, status, parsed, reporter, counts)
        end

      {:error, reason} ->
        reporter.("  falha ao ler #{path}: #{inspect(reason)}")
        %{counts | error: counts.error + 1}
    end
  end

  defp handle_existing(existing, slug, status, parsed, true, reporter, counts) do
    attrs = %{
      slug: slug,
      status: status,
      title: parsed.title,
      header: parsed.header,
      footer: parsed.footer,
      main_capacity: parsed.main_capacity,
      wait_enabled: parsed.wait_enabled,
      wait_intro: parsed.wait_intro,
      main_list: Enum.map(parsed.main_list, &Map.from_struct/1),
      wait_list: Enum.map(parsed.wait_list, &Map.from_struct/1)
    }

    case existing |> Event.changeset(attrs) |> Repo.update() do
      {:ok, _} ->
        reporter.("  sobrescrito: #{status} #{slug}")
        %{counts | ok: counts.ok + 1}

      {:error, changeset} ->
        reporter.("  erro ao sobrescrever #{slug}: #{inspect(changeset.errors)}")
        %{counts | error: counts.error + 1}
    end
  end

  defp handle_existing(_existing, slug, _status, _parsed, false, reporter, counts) do
    reporter.("  já existe (pulado): #{slug} — use --overwrite pra substituir")
    %{counts | skipped: counts.skipped + 1}
  end

  defp insert_new(slug, status, parsed, reporter, counts) do
    case Events.insert_imported(slug, status, parsed) do
      {:ok, _event} ->
        reporter.("  importado: #{status} #{slug}")
        %{counts | ok: counts.ok + 1}

      {:error, errors} ->
        reporter.("  erro em #{slug}: #{inspect(errors)}")
        %{counts | error: counts.error + 1}
    end
  end

  defp count_filled(list) do
    Enum.count(list, fn %{name: n} -> String.trim(n) != "" end)
  end
end

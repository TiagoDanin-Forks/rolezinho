defmodule RolezinhoWeb.DarkModeContrastTest do
  @moduledoc """
  A guard against the "invisible in dark mode" regression class.

  Any hard-coded `bg-white` in a template stays literally white regardless of
  the `data-theme` attribute, while text colors that use design tokens like
  `text-ink` invert with the theme. The combination is unreadable: on a page
  the user has switched to dark mode, `bg-white` + `text-ink` becomes white
  text on white background.

  The design system's contract is that every surface color is a theme token
  (`bg-base-100`, `bg-surface`, `bg-tint`, `bg-canvas`, `bg-ink`, ...). This
  file is the mechanical enforcement of that rule: no `bg-white` anywhere in
  `lib/rolezinho_web` or `storybook/`. If you actually need "always white"
  for some new reason, add an ADR under `docs/decisions/` explaining why.

  See `DESIGN.md` for the token vocabulary and `assets/css/app.css` for the
  values (light and dark).
  """
  use ExUnit.Case, async: true

  @roots ~w(lib/rolezinho_web storybook)

  test "no `bg-white` in application templates or storybook stories" do
    offenders = Enum.flat_map(@roots, &scan/1)

    assert offenders == [],
           format_offenders(offenders)
  end

  # Reads every file under `root`, walks it line-by-line keeping track of
  # whether the current line is inside a HEEx comment (`<!-- ... -->`), and
  # returns `{path, line_number, line}` for each hit that is NOT inside a
  # comment. This matters because we deliberately leave explanatory text
  # mentioning `bg-white` inside comments after the substitution.
  defp scan(root) do
    root
    |> Path.expand(File.cwd!())
    |> collect_files()
    |> Enum.flat_map(&scan_file/1)
  end

  defp collect_files(dir) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.flat_map(fn entry -> collect_files(Path.join(dir, entry)) end)
    else
      if String.ends_with?(dir, [".ex", ".exs", ".heex"]), do: [dir], else: []
    end
  end

  defp scan_file(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map_reduce(false, fn {line, i}, in_comment? ->
      # Update the multi-line comment tracker BEFORE deciding whether to
      # flag this line, so an opening `<!--` on this line counts it as a
      # comment line, and a closing `-->` this line is still comment.
      still_open? = update_comment_state(line, in_comment?)
      hit? = String.contains?(line, "bg-white") and not line_is_comment?(line, in_comment?)

      entry = if hit?, do: {path, i, line}, else: nil
      {entry, still_open?}
    end)
    |> elem(0)
    |> Enum.reject(&is_nil/1)
  end

  # Given the line and whether we were already inside a HEEx comment, return
  # whether the *next* line will be inside one. A single line can both open
  # and close a comment, in which case we exit again.
  defp update_comment_state(line, in_comment?) do
    open = String.contains?(line, "<!--")
    close = String.contains?(line, "-->")

    cond do
      in_comment? and close -> false
      in_comment? -> true
      open and close -> false
      open -> true
      true -> false
    end
  end

  # Excludes single-line Elixir comments (`# ...`), single-line HEEx comments
  # (`<!-- ... -->` on one line), and any line that is part of a multi-line
  # HEEx comment (either the opener, the body, or the closer).
  defp line_is_comment?(line, was_in_comment?) do
    trimmed = String.trim(line)

    was_in_comment? or
      String.starts_with?(trimmed, "#") or
      String.starts_with?(trimmed, "<!--") or
      String.contains?(trimmed, "-->")
  end

  defp format_offenders(list) do
    lines =
      Enum.map(list, fn {path, i, line} ->
        rel = Path.relative_to(path, File.cwd!())
        "  #{rel}:#{i}\n    #{String.trim(line)}"
      end)

    """
    Found `bg-white` in application templates. Use a theme token instead
    (see DESIGN.md and the @theme block in assets/css/app.css). The usual
    replacement is `bg-base-100`.

    #{Enum.join(lines, "\n")}
    """
  end
end

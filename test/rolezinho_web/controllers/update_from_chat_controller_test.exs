defmodule RolezinhoWeb.UpdateFromChatControllerTest do
  @moduledoc """
  `/atualizar.md` serves the LLM-facing docs as `text/markdown`.
  Contract we lock in:

    * 200 on GET.
    * Content-Type is `text/markdown; charset=utf-8` so a curl / an
      LLM fetcher sees plain markdown, not `text/html`.
    * The body contains the top-line heading and at least one
      example URL — a smoke test that the file wasn't accidentally
      truncated to zero bytes on release build.
  """
  use RolezinhoWeb.ConnCase, async: true

  test "GET /atualizar.md returns the docs as markdown", %{conn: conn} do
    conn = get(conn, ~p"/atualizar.md")

    assert conn.status == 200

    [content_type] = get_resp_header(conn, "content-type")
    assert content_type == "text/markdown; charset=utf-8"

    body = response(conn, 200)
    # Top-line heading.
    assert body =~ "# Rolezinho"
    # Contains a full-shape example URL.
    assert body =~ "/atualizar?"
    # Documents the four parameter families.
    assert body =~ "names[<i>]"
    assert body =~ "fields[<i>][<key>]"
    assert body =~ "checks[<i>]"
    assert body =~ "wait_names[<i>]"
  end

  test "the `<host>` placeholder is substituted with the endpoint's URL",
       %{conn: conn} do
    conn = get(conn, ~p"/atualizar.md")
    body = response(conn, 200)

    # The literal placeholder is gone — substitution ran.
    refute body =~ "https://<host>"

    # And the endpoint's real URL took its place. `Endpoint.url/0`
    # in test mode returns `http://localhost:4002` (test config), so
    # we check for that specific string: a regression that ships
    # `<host>` untouched would fail this assertion, and a regression
    # that swaps in the wrong URL would too.
    real_url = RolezinhoWeb.Endpoint.url()
    assert body =~ "#{real_url}/atualizar"
  end

  # Regression: the URL scheme moved event selection out of the LLM's
  # payload in 2026-09 (event slug lives in the path now, not in the
  # query). The docs must not tell LLMs to include `event=<slug>` —
  # doing so wastes their tokens and leaks a value they don't know.
  test "the docs no longer mention `event=<slug>`", %{conn: conn} do
    body = conn |> get(~p"/atualizar.md") |> response(200)

    refute body =~ "event=<slug>"
    refute body =~ "event="
  end

  # The base64 `encoded=` shortcut is meant to be surfaced upfront so
  # an LLM sees it while scanning the doc top-to-bottom, without
  # having to hunt through the parameter table. Guarding both the
  # header presence and the fact that it appears in the summary
  # portion (first quarter of the file) keeps the affordance
  # discoverable.
  test "docs surface the base64 `encoded=` shortcut upfront", %{conn: conn} do
    body = conn |> get(~p"/atualizar.md") |> response(200)

    assert body =~ "base64"
    assert body =~ "encoded="

    # The base64 section sits above the (much later) parameter
    # table, so a reader who bails after the first screen still
    # catches it.
    encoded_at = :binary.match(body, "base64-encoded query") |> elem(0)
    table_at = :binary.match(body, "## The full parameter reference") |> elem(0)
    assert encoded_at < table_at
  end

  # The compact aliases are the primary compression story now. They
  # must be documented with a clear table before the long-form
  # parameter reference, so an LLM scanning top-to-bottom sees them
  # before ever considering the verbose shape.
  test "docs put the compact aliases before the long-form reference", %{conn: conn} do
    body = conn |> get(~p"/atualizar.md") |> response(200)

    assert body =~ "## Compact aliases"
    # All the shorts get a row in the table.
    for short <- ["n=", "c=", "wn=", "wc=", "k=", "e="] do
      assert body =~ short, "expected `#{short}` documented in the compact aliases table"
    end

    compact_at = :binary.match(body, "## Compact aliases") |> elem(0)
    long_ref_at = :binary.match(body, "## The full parameter reference") |> elem(0)
    assert compact_at < long_ref_at
  end
end

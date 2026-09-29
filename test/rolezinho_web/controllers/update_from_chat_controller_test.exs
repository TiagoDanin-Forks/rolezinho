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
end

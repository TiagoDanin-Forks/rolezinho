defmodule RolezinhoWeb.UpdateFromChatController do
  @moduledoc """
  Serves `/atualizar.md` — a plain-Markdown document explaining the
  URL scheme that `RolezinhoWeb.UpdateFromChatLive` accepts.

  The intended reader is an LLM (WhatsApp assistant, an in-chat bot,
  a `curl | pbcopy` prompt-preparation script). Markdown so the LLM
  gets structure without HTML noise; served as `text/markdown; charset=utf-8`
  so a browser also renders it as plain text (most browsers do), and so
  a fetcher that respects the `Accept` header stays happy.

  The content lives on disk at `priv/static/docs/atualizar.md` and is
  read at request time \u2014 a hot edit in dev picks up without a
  restart, and prod serves the compiled version baked into the release.
  The file is under `priv/static/` so it also ships as a plain asset
  reachable at `/docs/atualizar.md`; the router alias `/atualizar.md`
  is a nicer URL for the LLM to remember.
  """
  use RolezinhoWeb, :controller

  @docs_path Application.app_dir(:rolezinho, "priv/static/docs/atualizar.md")

  # File is embedded at compile time so a fresh release never reaches
  # the filesystem for this response. In dev the module recompiles
  # when the .md changes (thanks to `@external_resource`), so editing
  # the doc feels live.
  @external_resource @docs_path
  @content File.read!(@docs_path)

  def docs(conn, _params) do
    # `put_resp_content_type/2` appends the charset itself, so pass
    # only the MIME here — passing "text/markdown; charset=utf-8"
    # ends up doubling it in the header.
    conn
    |> put_resp_content_type("text/markdown")
    # Small cache: LLMs may hit this every conversation. 5 min keeps
    # a chatty session light without pinning the copy for hours.
    |> put_resp_header("cache-control", "public, max-age=300")
    |> send_resp(200, @content)
  end
end

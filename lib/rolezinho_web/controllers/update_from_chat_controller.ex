defmodule RolezinhoWeb.UpdateFromChatController do
  @moduledoc """
  Serves `/atualizar.md` — a plain-Markdown document explaining the
  URL scheme that `RolezinhoWeb.UpdateFromChatLive` accepts.

  The intended reader is an LLM (WhatsApp assistant, an in-chat bot,
  a `curl | pbcopy` prompt-preparation script). Markdown so the LLM
  gets structure without HTML noise; served as `text/markdown; charset=utf-8`
  so a browser also renders it as plain text (most browsers do), and so
  a fetcher that respects the `Accept` header stays happy.

  The content lives on disk at `priv/static/docs/atualizar.md`,
  embedded into the module at compile time (`@external_resource` picks
  up hot edits in dev). At request time, every `https://<host>`
  placeholder in the doc is replaced with the endpoint's current
  public URL — so an LLM reading `/atualizar.md` sees the real domain
  (`https://rolezinho.lubien.dev` in prod, `http://localhost:4000`
  in dev) rather than a placeholder it has to imagine substituting.
  """
  use RolezinhoWeb, :controller

  alias RolezinhoWeb.Endpoint

  @docs_path Application.app_dir(:rolezinho, "priv/static/docs/atualizar.md")

  # File is embedded at compile time so a fresh release never reaches
  # the filesystem for this response. In dev the module recompiles
  # when the .md changes (thanks to `@external_resource`), so editing
  # the doc feels live.
  @external_resource @docs_path
  @template File.read!(@docs_path)

  def docs(conn, _params) do
    body = String.replace(@template, "https://<host>", public_url())

    # `put_resp_content_type/2` appends the charset itself, so pass
    # only the MIME here — passing "text/markdown; charset=utf-8"
    # ends up doubling it in the header.
    conn
    |> put_resp_content_type("text/markdown")
    # Small cache: LLMs may hit this every conversation. 5 min keeps
    # a chatty session light without pinning the copy for hours.
    |> put_resp_header("cache-control", "public, max-age=300")
    |> send_resp(200, body)
  end

  # The base URL to substitute for `https://<host>` in the template.
  # `Endpoint.url/0` reads scheme + host + port from the endpoint's
  # runtime config, which is already wired to `PHX_HOST` in prod
  # (`config/runtime.exs`). That gives us:
  #
  #   * dev  — `http://localhost:4000` (or whatever the dev port is;
  #     port is included because Endpoint.url/0 always emits it when
  #     scheme+port don't match the default pair).
  #   * prod — `https://rolezinho.lubien.dev` (or whatever
  #     PHX_HOST is).
  #
  # So we don't have to special-case localhost ourselves — the
  # endpoint's own scheme/port config already reflects that split.
  defp public_url, do: Endpoint.url()
end

defmodule RolezinhoWeb.Plugs.TxtRewrite do
  @moduledoc """
  Rewrites `/r/<slug>.txt` requests so they hit the raw controller
  at `/r/txt/<slug>` instead. Kept isolated to keep the router simple.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case conn.path_info do
      ["r", last] ->
        if String.ends_with?(last, ".txt") do
          slug = String.trim_trailing(last, ".txt")

          %{conn | path_info: ["r", "txt", slug], request_path: "/r/txt/" <> slug}
        else
          conn
        end

      _ ->
        conn
    end
  end
end

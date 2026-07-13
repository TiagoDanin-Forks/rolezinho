defmodule RolezinhoWeb.Plugs.TxtRewrite do
  @moduledoc """
  Rewrites URLs whose last segment carries a file extension the Phoenix router
  can't express directly:

    * `/r/<slug>.txt`           -> `/r/txt/<slug>`
    * `/r/<slug>/calendar.ics`  -> `/r/<slug>/calendar`
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

      ["r", slug, "calendar.ics"] ->
        %{conn | path_info: ["r", slug, "calendar"], request_path: "/r/#{slug}/calendar"}

      _ ->
        conn
    end
  end
end

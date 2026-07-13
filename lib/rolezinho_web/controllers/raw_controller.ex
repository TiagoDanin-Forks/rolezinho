defmodule RolezinhoWeb.RawController do
  @moduledoc "Serves the plain text version of an event at /r/:slug.txt"

  use RolezinhoWeb, :controller

  alias Rolezinho.Event
  alias Rolezinho.Events

  def show(conn, %{"slug" => slug}) do
    case Events.find(slug, visibility: :public) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Rolezinho não encontrado.")

      event ->
        conn
        |> put_resp_content_type("text/plain; charset=utf-8")
        |> send_resp(200, Event.to_text(event))
    end
  end
end

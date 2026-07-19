defmodule RolezinhoWeb.RawController do
  @moduledoc "Serves the plain text version of an event at /r/:slug.txt"

  use RolezinhoWeb, :controller

  alias Rolezinho.Event
  alias Rolezinho.Events
  alias RolezinhoWeb.Plugs.Admin

  def show(conn, %{"slug" => slug}) do
    case Events.find(slug, visibility: :public) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Rolezinho não encontrado.")

      event ->
        url = RolezinhoWeb.Endpoint.url() <> "/r/" <> event.slug
        unlocked? = unlocked?(conn, event)

        text_body =
          Event.to_text(event, url,
            strip_location: not unlocked?,
            hide_description: not unlocked?,
            hide_names: not unlocked?
          )

        conn
        |> put_resp_content_type("text/plain; charset=utf-8")
        |> send_resp(200, text_body)
    end
  end

  defp unlocked?(conn, %Event{} = event) do
    conn.assigns[:current_admin?] == true or
      not Event.password_protected?(event) or
      MapSet.member?(Admin.unlocked_events(conn), event.slug)
  end
end

defmodule RolezinhoWeb.CalendarController do
  @moduledoc "Serves .ics calendar files for events at /r/:slug/calendar.ics"

  use RolezinhoWeb, :controller

  alias Rolezinho.Event.Meta
  alias Rolezinho.Events

  def show(conn, %{"slug" => slug}) do
    with event when not is_nil(event) <- Events.find(slug, visibility: :public),
         {meta, _rest} <- Meta.extract(event.header),
         true <- Meta.has_date?(meta) do
      url = RolezinhoWeb.Endpoint.url() <> "/r/" <> slug
      ics = Meta.ics(meta, %{title: event.title, slug: slug, url: url, description: event.header})

      conn
      |> put_resp_content_type("text/calendar")
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{slug}.ics"))
      |> send_resp(200, ics)
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> text("Calendário não disponível para esse rolezinho.")
    end
  end
end

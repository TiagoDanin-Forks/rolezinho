defmodule RolezinhoWeb.CalendarController do
  @moduledoc "Serves .ics calendar files for events at /r/:slug/calendar.ics"

  use RolezinhoWeb, :controller

  alias Rolezinho.Event
  alias Rolezinho.Event.Meta
  alias Rolezinho.Events
  alias RolezinhoWeb.Plugs.Admin

  def show(conn, %{"slug" => slug}) do
    with %Event{} = event <- Events.find(slug, visibility: :public),
         :ok <- ensure_unlocked(conn, event),
         {meta, _rest} <- Meta.extract(event.header),
         true <- Meta.has_date?(meta) do
      url = RolezinhoWeb.Endpoint.url() <> "/r/" <> slug
      ics = Meta.ics(meta, %{title: event.title, slug: slug, url: url, description: event.header})

      conn
      |> put_resp_content_type("text/calendar")
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{slug}.ics"))
      |> send_resp(200, ics)
    else
      {:error, :locked} ->
        # The .ics carries the LOCATION field, so we refuse the download entirely
        # for password-protected events that the caller hasn't unlocked yet.
        conn
        |> put_status(:forbidden)
        |> text(
          "Este rolezinho é protegido por senha. Abra /r/#{slug} no navegador, " <>
            "digite a senha e tente de novo."
        )

      _ ->
        conn
        |> put_status(:not_found)
        |> text("Calendário não disponível para esse rolezinho.")
    end
  end

  defp ensure_unlocked(conn, %Event{} = event) do
    admin? = conn.assigns[:current_admin?] == true

    cond do
      admin? -> :ok
      not Event.password_protected?(event) -> :ok
      MapSet.member?(Admin.unlocked_events(conn), event.slug) -> :ok
      true -> {:error, :locked}
    end
  end
end

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
         %Meta{} = meta <- calendar_meta(event),
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

  # Prefers the real timestamp over the one recovered from the description.
  # "Quarta 19h" cannot say which Wednesday, so a calendar built from it is a
  # guess; starts_at is the actual moment, and an event that has one gets an
  # .ics that is right rather than plausible.
  defp calendar_meta(%Event{starts_at: %DateTime{} = starts_at} = event) do
    {parsed, _rest} = Meta.extract(event.header)
    local_time = shift_to_brt(starts_at)

    %Meta{
      local: event.local || parsed.local,
      date: DateTime.to_date(local_time),
      time: DateTime.to_time(local_time)
    }
  end

  defp calendar_meta(%Event{} = event) do
    {meta, _rest} = Meta.extract(event.header)
    meta
  end

  # Meta stores wall-clock time in BRT and converts back on the way out, so a
  # UTC timestamp has to be shifted before it goes in — otherwise the round trip
  # adds three hours to every event.
  defp shift_to_brt(%DateTime{} = utc), do: DateTime.add(utc, -3 * 3600, :second)

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

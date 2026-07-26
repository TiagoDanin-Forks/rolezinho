defmodule RolezinhoWeb.JoinController do
  @moduledoc """
  Puts someone on a list and issues the identity that keeps the row theirs.

  This is a controller rather than a LiveView event for one structural reason: a
  LiveView cannot write to the session, and the participant id has to land there
  to survive the next page load. So joining goes through a real request, and
  from then on the LiveView reads the id the session already holds.

  The id is issued here and never accepted from the client — a browser that
  could choose its own id could choose one already on somebody else's row.
  """
  use RolezinhoWeb, :controller

  alias Rolezinho.Event
  alias Rolezinho.Event.Policy
  alias Rolezinho.Event.Token
  alias Rolezinho.Events
  alias RolezinhoWeb.Plugs.Admin
  alias RolezinhoWeb.Plugs.Participant

  def create(conn, %{"slug" => slug} = params) do
    name = params |> Map.get("name", "") |> to_string()
    list = if Map.get(params, "list") == "wait", do: :wait, else: :main

    case Events.find(slug, visibility: :public) do
      %Event{} = event -> join(conn, event, list, name)
      nil -> not_found(conn)
    end
  end

  defp join(conn, %Event{} = event, list, name) do
    with :ok <- ensure_unlocked(conn, event),
         :ok <- ensure_open(conn, event),
         participant_id <- Token.generate_participant(),
         {:ok, _updated} <- add(event, list, name, participant_id) do
      conn
      |> Participant.put_participant(event.slug, participant_id)
      |> put_flash(:info, flash_for(list))
      |> redirect(to: ~p"/r/#{event.slug}")
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, message_for(reason))
        |> redirect(to: ~p"/r/#{event.slug}")
    end
  end

  defp add(event, :main, name, participant_id),
    do: Events.add_to_main(event, name, participant_id: participant_id)

  defp add(event, :wait, name, participant_id),
    do: Events.add_to_wait(event, name, participant_id: participant_id)

  # A password-gated event has to be unlocked before anyone can join it, or the
  # gate would only be hiding the list rather than protecting it.
  defp ensure_unlocked(conn, %Event{} = event) do
    unlocked? =
      conn.assigns.current_admin? or
        not Event.password_protected?(event) or
        MapSet.member?(Admin.unlocked_events(conn), event.slug)

    if unlocked?, do: :ok, else: {:error, :locked}
  end

  defp ensure_open(conn, %Event{} = event) do
    opts = [
      admin?: conn.assigns.current_admin?,
      organizer?: Participant.organizer?(conn, event)
    ]

    if Policy.can_join?(event, opts), do: :ok, else: {:error, :signups_locked}
  end

  defp not_found(conn) do
    conn
    |> put_flash(:error, "Rolezinho não encontrado.")
    |> redirect(to: ~p"/")
  end

  defp flash_for(:main), do: "Entrou na lista!"
  defp flash_for(:wait), do: "Entrou na reserva!"

  defp message_for(:locked), do: "Precisa da senha pra entrar nesse rolezinho."
  defp message_for(:signups_locked), do: "Este rolezinho está fechado para novas inscrições."
  defp message_for(:main_full), do: "Lista principal cheia."
  defp message_for(:empty_name), do: "Digite um nome."
  defp message_for(:wait_disabled), do: "Este rolezinho não tem lista de reserva."
  defp message_for(_), do: "Não deu pra entrar na lista."
end

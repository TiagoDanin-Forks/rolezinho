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
    size = params |> Map.get("qty") |> parse_size()

    case Events.find(slug, visibility: :public) do
      %Event{} = event -> join(conn, event, name, size, params)
      nil -> not_found(conn)
    end
  end

  defp join(conn, %Event{} = event, name, size, params) do
    with :ok <- ensure_unlocked(conn, event),
         :ok <- ensure_open(conn, event),
         {:ok, values} <- collect_answers(event, params),
         participant_id <- Token.generate_participant(),
         {:ok, _updated, placed} <-
           Events.add_party(event, name, size,
             participant_id: participant_id,
             values: values
           ) do
      conn
      |> Participant.put_participant(event.slug, participant_id)
      |> put_flash(:info, placement_message(placed))
      |> redirect(to: next_step(event))
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, message_for(reason))
        |> redirect(to: ~p"/r/#{event.slug}")
    end
  end

  # A party can be split across both lists, so the message says what actually
  # happened rather than assuming everyone got a slot.
  defp placement_message(%{main: main, wait: 0}), do: "#{people(main)} na lista!"
  defp placement_message(%{main: 0, wait: wait}), do: "#{people(wait)} na espera."

  defp placement_message(%{main: main, wait: wait}) do
    "#{people(main)} na lista e #{people(wait)} na espera."
  end

  defp people(1), do: "Você entrou"
  defp people(count), do: "#{count} entraram"

  # Paying is the next thing on someone's mind after getting a slot, so a paid
  # event routes there instead of dropping them back on the list to find the
  # key themselves (RN-11).
  defp next_step(%Event{} = event) do
    if payable?(event), do: ~p"/r/#{event.slug}/pagamento", else: ~p"/r/#{event.slug}"
  end

  defp payable?(%Event{price_cents: cents, pix_key: key}) do
    is_integer(cents) and cents > 0 and is_binary(key) and key != ""
  end

  # Answers to the organizer's questions (RN-62). Only the fields this event
  # actually asks for are read: anything else in the body is somebody sending
  # keys nobody asked about, and it does not get stored.
  defp collect_answers(%Event{} = event, params) do
    fields = event |> Events.form_fields() |> Enum.reject(& &1.locked)

    Enum.reduce_while(fields, {:ok, %{}}, fn field, {:ok, acc} ->
      value = params |> Map.get(field.id, "") |> to_string() |> String.trim()

      cond do
        value == "" and field.required -> {:halt, {:error, {:missing_field, field.label}}}
        value == "" -> {:cont, {:ok, acc}}
        # Bounded like every other anonymous write: an unbounded answer is a way
        # to fill the column.
        true -> {:cont, {:ok, Map.put(acc, field.id, String.slice(value, 0, 200))}}
      end
    end)
  end

  # A party size arriving from the client is bounded here, not trusted: the
  # stepper stops at nine, but the request does not have to come from it.
  defp parse_size(nil), do: 1

  defp parse_size(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {size, ""} when size >= 1 -> min(size, Event.max_party_size())
      _ -> 1
    end
  end

  defp parse_size(_), do: 1

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

  defp message_for(:locked), do: "Precisa da senha pra entrar nesse rolezinho."
  defp message_for(:signups_locked), do: "Este rolezinho está fechado para novas inscrições."
  defp message_for(:main_full), do: "Lista principal cheia."
  defp message_for(:empty_name), do: "Digite um nome."
  defp message_for(:wait_disabled), do: "Este rolezinho não tem lista de reserva."
  defp message_for(:invalid_party_size), do: "Escolha de 1 a 9 pessoas."

  defp message_for(:party_does_not_fit),
    do: "Não tem vaga pra todo mundo, e esse rolê não tem lista de espera."

  defp message_for({:missing_field, label}), do: "Preencha #{label}."

  defp message_for(_), do: "Não deu pra entrar na lista."
end

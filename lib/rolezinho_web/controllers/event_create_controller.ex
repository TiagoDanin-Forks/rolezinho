defmodule RolezinhoWeb.EventCreateController do
  @moduledoc """
  Creates an event and hands the organizer their secret.

  A controller rather than a LiveView event for the same structural reason
  joining is one: the organizer token has to land in the session to survive the
  next page load, and a LiveView cannot write there. Creating through a real
  request is what makes "whoever creates is the organizer" (RN-20) true for
  someone who is not the environment-wide admin.

  Without this, opening creation to everyone would hand people an event they
  could not administer — the token would exist in the database and nowhere else.
  """
  use RolezinhoWeb, :controller

  alias Rolezinho.Events
  alias RolezinhoWeb.Plugs.Participant

  def create(conn, %{"event" => params}) do
    case Events.create(params) do
      {:ok, event} ->
        conn
        |> Participant.put_organizer_token(event.slug, event.organizer_token)
        |> put_flash(:info, "Rolezinho criado! Manda o link no grupo.")
        |> redirect(to: ~p"/r/#{event.slug}")

      {:error, _errors} ->
        # The form posts, so a rejection cannot re-render in place. Rather than
        # smuggling every field back through the query string, it returns to the
        # empty form with the reason — the alternative was a URL carrying the
        # description in it.
        conn
        |> put_flash(:error, "Confira os campos e tente de novo.")
        |> redirect(to: ~p"/criar")
    end
  end
end

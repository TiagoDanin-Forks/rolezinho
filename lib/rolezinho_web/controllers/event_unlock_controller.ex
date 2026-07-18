defmodule RolezinhoWeb.EventUnlockController do
  @moduledoc """
  Accepts a password submission for a password-protected event and records the
  unlock in the browser session. Non-admin visitors need to POST here once per
  event before they can see the location or add themselves to any list.
  """

  use RolezinhoWeb, :controller

  alias Rolezinho.Events
  alias RolezinhoWeb.Plugs.Admin

  def unlock(conn, %{"slug" => slug} = params) do
    submitted = params |> Map.get("password", "") |> to_string()

    case Events.find(slug, visibility: :public) do
      nil ->
        conn
        |> put_flash(:error, "Rolezinho não encontrado.")
        |> redirect(to: ~p"/")

      event ->
        if Events.check_password(event, submitted) do
          conn
          |> Admin.put_unlocked_event(slug)
          |> put_flash(:info, "Senha confirmada.")
          |> redirect(to: ~p"/r/#{slug}")
        else
          conn
          |> put_flash(:error, "Senha inválida.")
          |> redirect(to: ~p"/r/#{slug}")
        end
    end
  end
end

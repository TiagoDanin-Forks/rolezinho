defmodule RolezinhoWeb.GroupUnlockController do
  @moduledoc """
  Accepts a password submission for a password-protected group and records the
  unlock in the browser session. Non-admin visitors need to POST here once per
  group before they can see anything on the group page — even the group's own
  name — and events in the group inherit that unlock (SECURITY.md §3).
  """

  use RolezinhoWeb, :controller

  alias Rolezinho.Groups
  alias RolezinhoWeb.Plugs.Admin

  def unlock(conn, %{"slug" => slug} = params) do
    submitted = params |> Map.get("password", "") |> to_string()

    case Groups.find(slug) do
      nil ->
        conn
        |> put_flash(:error, "Grupo não encontrado.")
        |> redirect(to: ~p"/")

      group ->
        if Groups.check_password(group, submitted) do
          # Always record the unlock in the browser session so anonymous
          # visitors carry the access across requests. When the visitor is
          # signed in, ALSO persist the unlock so the same GitHub account
          # keeps access on future devices and after cookie clears
          # (ADR-0002 durable-identity rule).
          _ = Groups.remember_unlock(conn.assigns[:current_user_id], group.id)

          conn
          |> Admin.put_unlocked_group(slug)
          |> put_flash(:info, "Senha confirmada.")
          |> redirect(to: ~p"/g/#{slug}")
        else
          conn
          |> put_flash(:error, "Senha inválida.")
          |> redirect(to: ~p"/g/#{slug}")
        end
    end
  end
end

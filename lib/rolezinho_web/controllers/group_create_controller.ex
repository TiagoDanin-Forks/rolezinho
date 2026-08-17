defmodule RolezinhoWeb.GroupCreateController do
  @moduledoc """
  Creates a group and, if it was created with a password, immediately unlocks
  it in the creator's session.

  A controller rather than a LiveView event for the same structural reason
  event creation is one: the unlock has to land in the session to survive the
  next page load, and a LiveView cannot write there. Creating with a password
  and *not* unlocking would send the creator to a page that shows only the
  password gate — the group they just made, hidden from them.

  Anyone can create a group. The password is what lets a non-admin edit it or
  add events to it later (there is no per-group organizer token); a passwordless
  group can only be edited by the platform admin.
  """

  use RolezinhoWeb, :controller

  alias Rolezinho.Groups
  alias RolezinhoWeb.Plugs.Admin

  def create(conn, %{"group" => params}) do
    case Groups.create(params) do
      {:ok, group} ->
        conn
        |> maybe_unlock(group)
        |> put_flash(:info, create_flash(group))
        |> redirect(to: ~p"/g/#{group.slug}")

      {:error, _errors} ->
        conn
        |> put_flash(:error, "Confira os campos e tente de novo.")
        |> redirect(to: ~p"/g/criar")
    end
  end

  # Auto-unlock avoids the alarming "you just created a group and can't see it"
  # first impression when someone sets a password on creation.
  defp maybe_unlock(conn, group) do
    if Rolezinho.Group.password_protected?(group),
      do: Admin.put_unlocked_group(conn, group.slug),
      else: conn
  end

  defp create_flash(group) do
    if Rolezinho.Group.password_protected?(group) do
      "Grupo criado! Guarda a senha — é ela que te deixa editar e adicionar rolês depois."
    else
      "Grupo criado, mas sem senha só o admin da plataforma consegue editar depois."
    end
  end
end

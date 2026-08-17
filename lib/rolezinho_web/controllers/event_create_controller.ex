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

  When a `group` slug arrives with the request, the event is created inside
  that group only if the caller has enough access to edit the group (admin, or
  the group is password-protected and unlocked in this session). Otherwise the
  event still gets created — but ungrouped, with a flash explaining why. This
  is deliberate: silently attaching to a group anyone can name would let a
  visitor drop noise into someone else's bundle.
  """
  use RolezinhoWeb, :controller

  alias Rolezinho.Group
  alias Rolezinho.Groups
  alias Rolezinho.Events
  alias RolezinhoWeb.Plugs.Participant

  def create(conn, %{"event" => params}) do
    admin? = conn.assigns.current_admin?
    unlocked_groups = conn.assigns[:unlocked_groups] || MapSet.new()
    requested_group_slug = params |> Map.get("group", "") |> to_string() |> String.trim()

    {group_id, group_flash, requested_group} =
      resolve_group(requested_group_slug, admin?, unlocked_groups)

    # An event in a group is not on the home page, so it doesn't need the
    # anonymous hidden-by-default treatment (its group already gates
    # visibility). Grant `:active` at the moment of grouping so the group page
    # actually shows it.
    create_opts =
      cond do
        admin? -> [admin?: true, group_id: group_id]
        not is_nil(group_id) -> [admin?: true, group_id: group_id]
        true -> []
      end

    case Events.create(params, create_opts) do
      {:ok, event} ->
        conn
        |> Participant.put_organizer_token(event.slug, event.organizer_token)
        |> put_flash(:info, create_flash(admin?, group_id))
        |> maybe_group_flash(group_flash)
        |> redirect(to: redirect_target(event, requested_group))

      {:error, _errors} ->
        # The form posts, so a rejection cannot re-render in place. Rather than
        # smuggling every field back through the query string, it returns to the
        # empty form with the reason — the alternative was a URL carrying the
        # description in it.
        conn
        |> put_flash(:error, "Confira os campos e tente de novo.")
        |> redirect(to: back_to_form(requested_group_slug))
    end
  end

  # `nil` when either no group was named, or one was named but the caller has
  # no right to add events to it. The second case ships a flash — a silent
  # "we ignored your group" would be surprising.
  defp resolve_group("", _admin?, _unlocked), do: {nil, nil, nil}

  defp resolve_group(slug, admin?, unlocked_groups) do
    case Groups.find(slug) do
      nil ->
        {nil, "Grupo não encontrado. O rolê foi criado fora de grupo.", nil}

      %Group{} = group ->
        if Group.editable_by?(group, admin?, unlocked_groups) do
          {group.id, nil, group}
        else
          {nil,
           "Você não tem acesso pra adicionar rolês nesse grupo. O rolê foi criado fora dele.",
           nil}
        end
    end
  end

  defp maybe_group_flash(conn, nil), do: conn
  # `:info` from the success flash already fills the info slot; use `:error` to
  # surface that something the caller asked for did not happen.
  defp maybe_group_flash(conn, message), do: put_flash(conn, :error, message)

  # Someone whose event will not show up on the home page needs to be told, or
  # they will look for it there and conclude it was not created.
  defp create_flash(_admin? = true, nil), do: "Rolezinho criado! Manda o link no grupo."

  defp create_flash(_admin?, group_id) when not is_nil(group_id),
    do: "Rolezinho criado no grupo!"

  defp create_flash(_admin?, _),
    do: "Rolezinho criado! Ele abre por link — manda no grupo pra galera entrar."

  # When creation was requested inside a valid group, send the organizer back to
  # the group so they see the new event in context.
  defp redirect_target(_event, %Group{} = group), do: ~p"/g/#{group.slug}"
  defp redirect_target(event, _), do: ~p"/r/#{event.slug}"

  defp back_to_form(""), do: ~p"/criar"
  defp back_to_form(slug), do: ~p"/criar?group=#{slug}"
end

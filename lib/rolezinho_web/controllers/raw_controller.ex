defmodule RolezinhoWeb.RawController do
  @moduledoc "Serves the plain text version of an event at /r/:slug.txt"

  use RolezinhoWeb, :controller

  alias Rolezinho.Event
  alias Rolezinho.Events
  alias Rolezinho.Group
  alias Rolezinho.Groups
  alias RolezinhoWeb.Plugs.Admin

  def show(conn, %{"slug" => slug}) do
    case Events.find(slug, visibility: :public) do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Rolezinho não encontrado.")

      event ->
        url = RolezinhoWeb.Endpoint.url() <> "/r/" <> event.slug
        unlocked? = unlocked?(conn, event)

        text_body =
          Event.to_text(event, url,
            strip_location: not unlocked?,
            hide_description: not unlocked?,
            hide_names: not unlocked?
          )

        conn
        |> put_resp_content_type("text/plain; charset=utf-8")
        |> send_resp(200, text_body)
    end
  end

  # An event's gate can come from two places: its own password, and the
  # password of the group it belongs to. Either one being closed is enough to
  # keep the sensitive fields out of the response — an event inside a locked
  # group is treated as locked even if the event itself has no password of its
  # own. Group unlock, in turn, bypasses both gates: that is the inheritance
  # the product spec calls for.
  defp unlocked?(conn, %Event{} = event) do
    admin? = conn.assigns[:current_admin?] == true

    cond do
      admin? -> true
      group_password_bypass?(conn, event) -> true
      group_password_gates?(conn, event) -> false
      not Event.password_protected?(event) -> true
      MapSet.member?(Admin.unlocked_events(conn), event.slug) -> true
      true -> false
    end
  end

  defp group_password_bypass?(_conn, %Event{group_id: nil}), do: false

  defp group_password_bypass?(conn, %Event{group_id: gid}) do
    with %Group{} = group <- Groups.get(gid),
         true <- Group.password_protected?(group) do
      MapSet.member?(Admin.unlocked_groups(conn), group.slug)
    else
      _ -> false
    end
  end

  defp group_password_gates?(_conn, %Event{group_id: nil}), do: false

  defp group_password_gates?(_conn, %Event{group_id: gid}) do
    case Groups.get(gid) do
      %Group{} = group -> Group.password_protected?(group)
      _ -> false
    end
  end
end

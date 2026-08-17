defmodule RolezinhoWeb.Plugs.Admin do
  @moduledoc """
  Plug helpers for admin authentication and per-event / per-group unlock
  sessions.

  Admin state lives in the session as `:admin?`. Per-event unlocks live in
  `:unlocked_events`, per-group unlocks in `:unlocked_groups` — both are
  MapSets of slugs. LiveViews read them via `on_mount` so gated UI can be
  rendered without a full page reload.

  A group unlock also unlocks the events in that group: `EventLive` composes
  the two checks. See `SECURITY.md` §3 for the reasoning behind sharing the
  gate.
  """

  import Plug.Conn

  @doc """
  Assigns `:current_admin?`, `:unlocked_events`, and `:unlocked_groups` on the
  connection from the session.
  """
  def fetch_admin(conn, _opts) do
    conn
    |> assign(:current_admin?, get_session(conn, :admin?) == true)
    |> assign(:unlocked_events, unlocked_events(conn))
    |> assign(:unlocked_groups, unlocked_groups(conn))
  end

  @doc "Reads the set of event slugs unlocked in the current session."
  @spec unlocked_events(Plug.Conn.t()) :: MapSet.t()
  def unlocked_events(conn) do
    session_mapset(get_session(conn, :unlocked_events))
  end

  @doc "Reads the set of group slugs unlocked in the current session."
  @spec unlocked_groups(Plug.Conn.t()) :: MapSet.t()
  def unlocked_groups(conn) do
    session_mapset(get_session(conn, :unlocked_groups))
  end

  @doc "Puts a slug into the set of unlocked events for this session."
  def put_unlocked_event(conn, slug) do
    put_session(conn, :unlocked_events, MapSet.put(unlocked_events(conn), slug))
  end

  @doc "Puts a slug into the set of unlocked groups for this session."
  def put_unlocked_group(conn, slug) do
    put_session(conn, :unlocked_groups, MapSet.put(unlocked_groups(conn), slug))
  end

  @doc "Halts with a 403 response when the current session is not an admin."
  def require_admin(conn, _opts) do
    if get_session(conn, :admin?) == true do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Você precisa fazer login como admin.")
      |> Phoenix.Controller.redirect(to: "/admin/login")
      |> halt()
    end
  end

  @doc """
  Checks a submitted password against the configured admin password.

  Uses `fetch_env!/2` rather than a defaulted lookup: a silent fallback here
  would mean a misconfigured deploy accepting a password nobody chose. Production
  also refuses to boot without `ADMIN_PASSWORD` (see `config/runtime.exs`), so
  reaching this with no value configured is a bug worth crashing on.
  """
  def valid_password?(password) when is_binary(password) do
    expected = Application.fetch_env!(:rolezinho, :admin_password)
    Plug.Crypto.secure_compare(password, expected)
  end

  def valid_password?(_), do: false

  @doc "on_mount hook for LiveViews that need to know if the user is admin."
  def on_mount(:fetch, _params, session, socket) do
    admin? = Map.get(session, "admin?") == true

    {:cont,
     socket
     |> Phoenix.Component.assign(:current_admin?, admin?)
     |> Phoenix.Component.assign(:unlocked_events, session_unlocked(session, "unlocked_events"))
     |> Phoenix.Component.assign(:unlocked_groups, session_unlocked(session, "unlocked_groups"))}
  end

  def on_mount(:require_admin, _params, session, socket) do
    if Map.get(session, "admin?") == true do
      {:cont,
       socket
       |> Phoenix.Component.assign(:current_admin?, true)
       |> Phoenix.Component.assign(:unlocked_events, session_unlocked(session, "unlocked_events"))
       |> Phoenix.Component.assign(:unlocked_groups, session_unlocked(session, "unlocked_groups"))}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Você precisa fazer login como admin.")
       |> Phoenix.LiveView.redirect(to: "/admin/login")}
    end
  end

  defp session_unlocked(session, key), do: session_mapset(Map.get(session, key))

  defp session_mapset(%MapSet{} = set), do: set
  defp session_mapset(list) when is_list(list), do: MapSet.new(list)
  defp session_mapset(_), do: MapSet.new()
end

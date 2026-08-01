defmodule RolezinhoWeb.Plugs.Admin do
  @moduledoc """
  Plug helpers for admin authentication and per-event unlock sessions.

  Admin state lives in the session as `:admin?`. Per-event unlocks live in
  `:unlocked_events` as a MapSet of slugs. LiveViews read both via `on_mount`
  so gated UI can be rendered without a full page reload.
  """

  import Plug.Conn

  @doc "Assigns `:current_admin?` and `:unlocked_events` on the connection from the session."
  def fetch_admin(conn, _opts) do
    conn
    |> assign(:current_admin?, get_session(conn, :admin?) == true)
    |> assign(:unlocked_events, unlocked_events(conn))
  end

  @doc "Reads the set of slugs unlocked in the current session."
  @spec unlocked_events(Plug.Conn.t()) :: MapSet.t()
  def unlocked_events(conn) do
    case get_session(conn, :unlocked_events) do
      %MapSet{} = set -> set
      list when is_list(list) -> MapSet.new(list)
      _ -> MapSet.new()
    end
  end

  @doc "Puts a slug into the set of unlocked events for this session."
  def put_unlocked_event(conn, slug) do
    put_session(conn, :unlocked_events, MapSet.put(unlocked_events(conn), slug))
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
    unlocked = session_unlocked(session)

    {:cont,
     socket
     |> Phoenix.Component.assign(:current_admin?, admin?)
     |> Phoenix.Component.assign(:unlocked_events, unlocked)}
  end

  def on_mount(:require_admin, _params, session, socket) do
    if Map.get(session, "admin?") == true do
      {:cont,
       socket
       |> Phoenix.Component.assign(:current_admin?, true)
       |> Phoenix.Component.assign(:unlocked_events, session_unlocked(session))}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Você precisa fazer login como admin.")
       |> Phoenix.LiveView.redirect(to: "/admin/login")}
    end
  end

  defp session_unlocked(session) do
    case Map.get(session, "unlocked_events") do
      %MapSet{} = set -> set
      list when is_list(list) -> MapSet.new(list)
      _ -> MapSet.new()
    end
  end
end

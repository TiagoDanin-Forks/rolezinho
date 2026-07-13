defmodule RolezinhoWeb.Plugs.Admin do
  @moduledoc """
  Plug helpers for admin authentication.

  Admin state lives in the session as `:admin?`. LiveViews read it via
  `on_mount` so admin-only UI can be rendered without a full page reload.
  """

  import Plug.Conn

  @doc "Assigns `:current_admin?` on the connection from the session."
  def fetch_admin(conn, _opts) do
    admin? = get_session(conn, :admin?) == true
    assign(conn, :current_admin?, admin?)
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

  @doc "Checks a submitted password against the configured admin password."
  def valid_password?(password) when is_binary(password) do
    expected = Application.get_env(:rolezinho, :admin_password, "admin")
    Plug.Crypto.secure_compare(password, expected)
  end

  def valid_password?(_), do: false

  @doc "on_mount hook for LiveViews that need to know if the user is admin."
  def on_mount(:fetch, _params, session, socket) do
    admin? = Map.get(session, "admin?") == true
    {:cont, Phoenix.Component.assign(socket, :current_admin?, admin?)}
  end

  def on_mount(:require_admin, _params, session, socket) do
    if Map.get(session, "admin?") == true do
      {:cont, Phoenix.Component.assign(socket, :current_admin?, true)}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Você precisa fazer login como admin.")
       |> Phoenix.LiveView.redirect(to: "/admin/login")}
    end
  end
end

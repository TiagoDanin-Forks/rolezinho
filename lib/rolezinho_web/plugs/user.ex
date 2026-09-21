defmodule RolezinhoWeb.Plugs.User do
  @moduledoc """
  Resolves the signed-in user, if any, for the current request or socket.

  Under ADR-0002 accounts exist only for creation. This plug therefore only
  populates two assigns — `:current_user` (a `%Rolezinho.Accounts.User{}` or
  `nil`) and `:current_user_id` (integer or `nil`) — and does **not** enforce
  authentication. Enforcement is the creation controllers' and LiveViews'
  responsibility.

  The session-held key is the integer id, not the user struct: a stale
  struct would mean a renamed GitHub login shows the old value across
  requests, and there is no upside to trading a database read for that.
  """

  import Plug.Conn

  alias Rolezinho.Accounts

  @session_key :current_user_id

  @doc """
  Assigns `:current_user_id` and `:current_user` from the session, and —
  when a user is signed in — merges their persisted group unlocks into the
  session-scoped `:unlocked_groups` MapSet.

  The Admin plug set `:unlocked_groups` earlier in the pipeline from the
  cookie session; here we widen it with what the DB says this GitHub user
  has unlocked before, on any device. Anonymous requests skip the merge
  entirely and keep the session-only set.
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, @session_key)
    user = Accounts.get_user(user_id)

    conn
    |> assign(:current_user_id, user_id)
    |> assign(:current_user, user)
    |> merge_persisted_group_unlocks(user_id)
  end

  defp merge_persisted_group_unlocks(conn, nil), do: conn

  defp merge_persisted_group_unlocks(conn, user_id) do
    persisted = Rolezinho.Groups.unlocked_slugs_for_user(user_id)
    session = conn.assigns[:unlocked_groups] || MapSet.new()
    assign(conn, :unlocked_groups, MapSet.union(session, persisted))
  end

  @doc """
  Puts a user's id in the signed session.

  Called from the OAuth callback after a successful sign-in.
  """
  def put_current_user(conn, user_id) when is_integer(user_id) do
    conn
    # Regenerating the session on login is standard hygiene against fixation:
    # anything a pre-login attacker might have left in the session cannot
    # ride along into the authenticated one.
    |> configure_session(renew: true)
    |> put_session(@session_key, user_id)
  end

  @doc "Clears the session-held user id. Called from logout."
  def clear_current_user(conn) do
    conn
    |> delete_session(@session_key)
    |> configure_session(renew: true)
  end

  @doc "Reads the session-held user id from either a `conn` or a raw session map."
  @spec current_user_id(Plug.Conn.t() | map()) :: integer() | nil
  def current_user_id(%Plug.Conn{} = conn), do: get_session(conn, @session_key)

  def current_user_id(session) when is_map(session) do
    case Map.get(session, "current_user_id") || Map.get(session, @session_key) do
      id when is_integer(id) -> id
      _ -> nil
    end
  end

  @doc """
  on_mount hook for public LiveViews.

  Assigns `:current_user` and `:current_user_id` from the session so the same
  identity a plug reads on an HTTP request is available on the socket. The
  socket is the surface a `handle_event` would touch, so this mirrors the
  shape of `RolezinhoWeb.Plugs.Admin.on_mount/4`.

  Enforcement ("you must be signed in to see this LiveView") is deliberately
  not here — the two creation LiveViews check it themselves in `mount/3`, so
  they can carry a `return_to` from `params` cleanly. See
  `RolezinhoWeb.EventNewLive` and `RolezinhoWeb.GroupNewLive`.
  """
  def on_mount(:fetch, _params, session, socket) do
    user_id = current_user_id(session)
    user = Accounts.get_user(user_id)

    socket =
      socket
      |> Phoenix.Component.assign(:current_user_id, user_id)
      |> Phoenix.Component.assign(:current_user, user)

    # Same widening the plug does on the conn: merge persisted unlocks with
    # the session set the Admin `on_mount` seeded a moment ago.
    socket =
      if user_id do
        persisted = Rolezinho.Groups.unlocked_slugs_for_user(user_id)
        session_set = socket.assigns[:unlocked_groups] || MapSet.new()
        Phoenix.Component.assign(socket, :unlocked_groups, MapSet.union(session_set, persisted))
      else
        socket
      end

    {:cont, socket}
  end
end

defmodule RolezinhoWeb.Plugs.Participant do
  @moduledoc """
  Resolves who the current browser is, per event.

  This app has no accounts, so identity is a signed session entry mapping a slug
  to the opaque id stored on the matching attendee row. Presenting the id is
  what claims the row — which is why it lives in the signed session rather than
  in a readable cookie or a URL.

  The identity is per event on purpose. A single id across every event would let
  one leaked value claim rows in lists the person never joined, and there is no
  account boundary here to contain that.

  Three roles come out of this, and they are the whole access model:

    * visitor — has not joined; may read whatever the event exposes
    * participant — holds the id on a row; may act on **that row only** (RN-12,
      RN-21)
    * organizer — holds the event's `organizer_token`; may act on every row of
      **that event** (RN-13, RN-23)

  The environment-wide admin password sits above all three and stays as a
  support bypass; see `SECURITY.md`.
  """

  import Plug.Conn

  alias Rolezinho.Events

  @session_key "participants"
  @organizer_key "organizer_tokens"

  @doc """
  Assigns `:participants` and `:organizer_tokens` from the session.

  Both are maps keyed by slug, so a browser can hold a row in one event and
  organize another without the two interfering.
  """
  def fetch_participant(conn, _opts) do
    conn
    |> assign(:participants, participants(conn))
    |> assign(:organizer_tokens, organizer_tokens(conn))
  end

  @doc "Reads the slug-to-participant-id map for this session."
  @spec participants(Plug.Conn.t()) :: %{String.t() => String.t()}
  def participants(conn), do: session_map(get_session(conn, @session_key))

  @doc "Reads the slug-to-organizer-token map for this session."
  @spec organizer_tokens(Plug.Conn.t()) :: %{String.t() => String.t()}
  def organizer_tokens(conn), do: session_map(get_session(conn, @organizer_key))

  @doc "Records that this browser holds `participant_id` on `slug`."
  def put_participant(conn, slug, participant_id)
      when is_binary(slug) and is_binary(participant_id) do
    put_session(conn, @session_key, Map.put(participants(conn), slug, participant_id))
  end

  @doc "Forgets this browser's claim on `slug` — used when leaving a list."
  def delete_participant(conn, slug) when is_binary(slug) do
    put_session(conn, @session_key, Map.delete(participants(conn), slug))
  end

  @doc "Records that this browser holds the organizer token for `slug`."
  def put_organizer_token(conn, slug, token) when is_binary(slug) and is_binary(token) do
    put_session(conn, @organizer_key, Map.put(organizer_tokens(conn), slug, token))
  end

  @doc """
  Returns the participant id this browser holds on `slug`, or `nil`.

  ## Examples

      iex> participant_id(conn, "volei")
      "3Yx...ZQ"
  """
  @spec participant_id(Plug.Conn.t() | map(), String.t()) :: String.t() | nil
  def participant_id(%Plug.Conn{} = conn, slug), do: Map.get(participants(conn), slug)

  def participant_id(session, slug) when is_map(session) do
    session |> Map.get(@session_key) |> session_map() |> Map.get(slug)
  end

  @doc """
  Returns true when this browser holds the organizer token for `event`.

  The token is compared against the one stored on the event, so a stale token
  from a session that predates a rotation does not carry over.
  """
  @spec organizer?(Plug.Conn.t() | map(), Rolezinho.Event.t()) :: boolean()
  def organizer?(conn_or_session, event)

  def organizer?(%Plug.Conn{} = conn, event) do
    conn |> organizer_tokens() |> token_matches?(event)
  end

  def organizer?(session, event) when is_map(session) do
    session |> Map.get(@organizer_key) |> session_map() |> token_matches?(event)
  end

  @doc """
  Resolves the organizer token in `params` and records it in the session.

  This is how the creation link works: the organizer opens the event with its
  token once and the browser remembers it from then on, so the secret stops
  travelling in the URL.
  """
  @spec claim_organizer(Plug.Conn.t(), String.t() | nil) :: Plug.Conn.t()
  def claim_organizer(conn, token) when is_binary(token) and token != "" do
    case Events.get_by_organizer_token(token) do
      %Rolezinho.Event{slug: slug} -> put_organizer_token(conn, slug, token)
      nil -> conn
    end
  end

  def claim_organizer(conn, _), do: conn

  @doc """
  on_mount hook assigning the same identity to a LiveView socket.

  The socket does not pass through the plug pipeline, so a LiveView that skips
  this sees no participant and no organizer at all.
  """
  def on_mount(:fetch, _params, session, socket) do
    {:cont,
     socket
     |> Phoenix.Component.assign(:participants, session_map(Map.get(session, @session_key)))
     |> Phoenix.Component.assign(
       :organizer_tokens,
       session_map(Map.get(session, @organizer_key))
     )}
  end

  defp token_matches?(tokens, %Rolezinho.Event{slug: slug, organizer_token: expected})
       when is_binary(expected) and expected != "" do
    case Map.get(tokens, slug) do
      token when is_binary(token) and token != "" -> Plug.Crypto.secure_compare(token, expected)
      _ -> false
    end
  end

  defp token_matches?(_tokens, _event), do: false

  defp session_map(%{} = map), do: map
  defp session_map(_), do: %{}
end

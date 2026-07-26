defmodule RolezinhoWeb.Plugs.ParticipantTest do
  use RolezinhoWeb.ConnCase, async: true

  alias Rolezinho.Events
  alias RolezinhoWeb.Plugs.Participant

  defp create_event(attrs \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei-#{System.unique_integer([:positive])}",
      "description" => "End: Praia",
      "main_size" => "3",
      "wait_size" => "0"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  defp session_conn(conn), do: Plug.Test.init_test_session(conn, %{})

  describe "participant identity" do
    test "a browser that never joined holds nothing", %{conn: conn} do
      conn = conn |> session_conn() |> Participant.fetch_participant([])

      assert conn.assigns.participants == %{}
      assert Participant.participant_id(conn, "volei") == nil
    end

    test "joining records the claim under that event's slug", %{conn: conn} do
      conn =
        conn
        |> session_conn()
        |> Participant.put_participant("volei", "abc123")

      assert Participant.participant_id(conn, "volei") == "abc123"
    end

    test "a claim on one event does not carry to another", %{conn: conn} do
      conn =
        conn
        |> session_conn()
        |> Participant.put_participant("volei", "abc123")

      assert Participant.participant_id(conn, "churrasco") == nil
    end

    test "leaving forgets the claim", %{conn: conn} do
      conn =
        conn
        |> session_conn()
        |> Participant.put_participant("volei", "abc123")
        |> Participant.delete_participant("volei")

      assert Participant.participant_id(conn, "volei") == nil
    end
  end

  describe "organizer identity" do
    test "holding the event's token makes the browser its organizer", %{conn: conn} do
      event = create_event()

      conn =
        conn
        |> session_conn()
        |> Participant.put_organizer_token(event.slug, event.organizer_token)

      assert Participant.organizer?(conn, event)
    end

    test "a token from another event does not administer this one", %{conn: conn} do
      event = create_event()
      other = create_event()

      conn =
        conn
        |> session_conn()
        |> Participant.put_organizer_token(event.slug, other.organizer_token)

      refute Participant.organizer?(conn, event)
    end

    test "a made-up token administers nothing", %{conn: conn} do
      event = create_event()

      conn =
        conn
        |> session_conn()
        |> Participant.put_organizer_token(event.slug, "guessed-token")

      refute Participant.organizer?(conn, event)
    end

    test "a browser holding no token is not the organizer", %{conn: conn} do
      event = create_event()
      conn = conn |> session_conn() |> Participant.fetch_participant([])

      refute Participant.organizer?(conn, event)
    end

    test "claiming resolves a valid token into the session", %{conn: conn} do
      event = create_event()

      conn =
        conn
        |> session_conn()
        |> Participant.claim_organizer(event.organizer_token)

      assert Participant.organizer?(conn, event)
    end

    test "claiming an unknown token leaves the session untouched", %{conn: conn} do
      event = create_event()

      conn =
        conn
        |> session_conn()
        |> Participant.claim_organizer("not-a-real-token")

      refute Participant.organizer?(conn, event)
      assert Participant.organizer_tokens(conn) == %{}
    end
  end

  describe "on_mount :fetch" do
    test "carries the same identity onto a socket", %{conn: _conn} do
      session = %{
        "participants" => %{"volei" => "abc123"},
        "organizer_tokens" => %{"volei" => "secret"}
      }

      assert {:cont, socket} =
               Participant.on_mount(:fetch, %{}, session, %Phoenix.LiveView.Socket{})

      assert socket.assigns.participants == %{"volei" => "abc123"}
      assert socket.assigns.organizer_tokens == %{"volei" => "secret"}
    end

    test "a socket with no session sees no identity at all" do
      assert {:cont, socket} = Participant.on_mount(:fetch, %{}, %{}, %Phoenix.LiveView.Socket{})

      assert socket.assigns.participants == %{}
      assert socket.assigns.organizer_tokens == %{}
    end

    test "reads the participant id out of a raw session map" do
      session = %{"participants" => %{"volei" => "abc123"}}

      assert Participant.participant_id(session, "volei") == "abc123"
      assert Participant.participant_id(session, "outro") == nil
    end
  end
end

defmodule RolezinhoWeb.GroupPasswordGatingTest do
  @moduledoc """
  A group's password gates every event inside it, on every surface — the
  event page, the .txt endpoint, the .ics endpoint. These tests hold that
  contract together: whoever unlocks the group has access to its events, and
  nobody else does, no matter which endpoint they hit.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events
  alias Rolezinho.Groups

  defp create_group(overrides \\ %{}) do
    defaults = %{"name" => "Grupo", "slug" => "grp", "visibility" => "public"}
    {:ok, group} = Groups.create(Map.merge(defaults, overrides))
    group
  end

  defp create_event(group_id, overrides) do
    defaults = %{
      "title" => "Rolê Dentro",
      "slug" => "dentro-1",
      "description" => "",
      "local" => "Rua Secreta",
      "date" => "2026-07-15",
      "time" => "",
      "main_size" => "3",
      "wait_size" => "0",
      "password" => ""
    }

    {:ok, event} =
      Events.create(Map.merge(defaults, overrides), admin?: true, group_id: group_id)

    event
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  defp unlocked_group_conn(conn, slug) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:unlocked_groups, MapSet.new([slug]))
  end

  describe "event in a password-protected group, visitor has not unlocked" do
    setup do
      group = create_group(%{"slug" => "trancado", "password" => "senha"})
      event = create_event(group.id, %{})
      %{group: group, event: event}
    end

    test "hitting the event page redirects to the group unlock", %{
      conn: conn,
      group: group,
      event: event
    } do
      # `live/2` follows push_navigate by design when `phx-live-link` fires.
      assert {:error, {:live_redirect, %{to: "/g/" <> _}}} = live(conn, ~p"/r/#{event.slug}")

      # And check the target is the group.
      {:error, {:live_redirect, %{to: to}}} = live(conn, ~p"/r/#{event.slug}")
      assert to == "/g/#{group.slug}"
    end

    test "raw .txt endpoint hides the location", %{conn: conn, event: event} do
      conn = get(conn, "/r/#{event.slug}.txt")
      assert conn.status == 200
      refute conn.resp_body =~ "Local: Rua Secreta"
    end

    test "calendar.ics endpoint refuses (403)", %{conn: conn, event: event} do
      conn = get(conn, "/r/#{event.slug}/calendar.ics")
      assert conn.status == 403
    end

    test "a locked visitor cannot join by posting straight to /r/:slug/join", %{
      conn: conn,
      event: event
    } do
      # Bypassing the LiveView redirect by hitting the join endpoint directly
      # must still fail: the join controller enforces the same gate.
      post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Alice"})

      assert Events.find(event.slug).main_list |> Enum.all?(&(&1.name == ""))
    end
  end

  describe "event in a password-protected group, group unlocked" do
    setup %{conn: conn} do
      group = create_group(%{"slug" => "aberto", "password" => "s"})
      event = create_event(group.id, %{})
      %{conn: unlocked_group_conn(conn, group.slug), group: group, event: event}
    end

    test "event page renders normally (location visible, no unlock panel)", %{
      conn: conn,
      event: event
    } do
      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "Rua Secreta"
      refute has_element?(view, "#unlock-form-#{event.slug}")
    end

    test "the event's OWN password is also bypassed when the group is unlocked", %{
      conn: conn,
      group: group
    } do
      # An event with its own password on top of the group's. The spec says
      # group unlock inherits to events — the event's own gate must yield too.
      {:ok, event} =
        Events.create(
          %{
            "title" => "Extra",
            "slug" => "extra-1",
            "description" => "",
            "local" => "Rua Extra",
            "date" => "",
            "time" => "",
            "main_size" => "3",
            "wait_size" => "0",
            "password" => "own-password"
          },
          admin?: true,
          group_id: group.id
        )

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      assert html =~ "Rua Extra"
      refute html =~ "protegida por senha"
    end

    test "raw .txt endpoint reveals the location", %{conn: conn, event: event} do
      conn = get(conn, "/r/#{event.slug}.txt")
      assert conn.resp_body =~ "Local: Rua Secreta"
    end

    test "calendar.ics endpoint serves the file", %{conn: conn, event: event} do
      conn = get(conn, "/r/#{event.slug}/calendar.ics")
      assert conn.status == 200
      assert conn.resp_body =~ "LOCATION:Rua Secreta"
    end
  end

  describe "event in a passwordless group" do
    setup do
      group = create_group()
      event = create_event(group.id, %{})
      %{group: group, event: event}
    end

    test "no redirect — the event page opens", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      # Location visible because the event has no password of its own.
      assert html =~ "Rua Secreta"
    end
  end

  describe "hidden event inside a password-protected group" do
    setup %{conn: conn} do
      group = create_group(%{"slug" => "phg", "password" => "s"})
      event = create_event(group.id, %{"slug" => "phe"})
      {:ok, event} = Events.set_hidden(event, true)

      %{conn: unlocked_group_conn(conn, group.slug), group: group, event: event}
    end

    test "does not appear on the group page (even to the unlocked visitor)", %{
      conn: conn,
      group: group,
      event: event
    } do
      {:ok, _view, html} = live(conn, ~p"/g/#{group.slug}")
      refute html =~ event.title
    end

    test "is still reachable by direct URL for the unlocked visitor", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      assert html =~ "Rua Secreta"
    end
  end

  describe "admin bypass on group-gated events" do
    setup %{conn: conn} do
      group = create_group(%{"slug" => "adm-group", "password" => "s"})
      event = create_event(group.id, %{})
      %{conn: admin_conn(conn), group: group, event: event}
    end

    test "admin sees the event without unlocking the group", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      assert html =~ "Rua Secreta"
    end
  end
end

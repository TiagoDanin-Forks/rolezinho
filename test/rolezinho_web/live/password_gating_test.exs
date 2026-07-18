defmodule RolezinhoWeb.PasswordGatingTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp create_event(attrs) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "pg",
      "description" => "",
      "local" => "",
      "date" => "",
      "time" => "",
      "main_size" => "3",
      "wait_size" => "3",
      "password" => ""
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  defp unlocked_conn(conn, slug) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:unlocked_events, MapSet.new([slug]))
  end

  describe "locked event (no admin, no unlock)" do
    setup do
      event =
        create_event(%{
          "slug" => "trancado",
          "password" => "senha123",
          "local" => "Rua Secreta",
          "date" => "2026-07-15"
        })

      %{event: event}
    end

    test "hides the location and shows an unlock form", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      refute html =~ "Rua Secreta"
      assert html =~ "Rolezinho protegido por senha"
      assert html =~ "unlock-form-#{event.slug}"
      # Google Calendar button gone since location is a factor + we don't want to leak
      assert html =~ "Digite a senha pra ver o local"
    end

    test "hides the join form and shows a hint instead", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      refute html =~ "id=\"add-main-form\""
      refute html =~ "id=\"add-wait-form\""
      assert html =~ "Digite a senha acima pra entrar na lista"
    end

    test "add_to_main from a locked non-admin socket flashes an error", %{
      conn: conn,
      event: event
    } do
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      html = render_hook(view, "add_to_main", %{"name" => "Alice"})
      assert html =~ "Precisa da senha"

      # And the DB reflects no changes
      assert Events.find(event.slug).main_list |> Enum.all?(&(&1.name == ""))
    end

    test "raw .txt endpoint strips the Local: line", %{conn: conn, event: event} do
      # Route `.txt` at `/r/:slug.txt` is rewritten to `/r/txt/:slug` by the plug.
      conn = get(conn, "/r/#{event.slug}.txt")
      assert conn.status == 200
      refute conn.resp_body =~ "Local: Rua Secreta"
      # Everything else stays
      assert conn.resp_body =~ "Vôlei"
    end

    test "calendar.ics endpoint refuses to serve when locked", %{conn: conn, event: event} do
      conn = get(conn, "/r/#{event.slug}/calendar.ics")
      assert conn.status == 403
      assert conn.resp_body =~ "senha"
    end

    test "calendar buttons are hidden in the widget", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      refute html =~ "Google Calendar"
      refute html =~ "Apple / .ics"
    end
  end

  describe "unlock flow via POST /r/:slug/unlock" do
    setup do
      event =
        create_event(%{
          "slug" => "abrir",
          "password" => "abc",
          "local" => "Um lugar"
        })

      %{event: event}
    end

    test "wrong password stays locked", %{conn: conn, event: event} do
      conn = post(conn, ~p"/r/#{event.slug}/unlock", %{"password" => "errada"})
      assert redirected_to(conn) == "/r/#{event.slug}"
      refute Plug.Conn.get_session(conn, :unlocked_events) |> is_map()
    end

    test "right password unlocks the session for this slug", %{conn: conn, event: event} do
      conn = post(conn, ~p"/r/#{event.slug}/unlock", %{"password" => "abc"})
      assert redirected_to(conn) == "/r/#{event.slug}"

      unlocked = Plug.Conn.get_session(conn, :unlocked_events)
      assert MapSet.member?(unlocked, event.slug)
    end
  end

  describe "with session unlock" do
    setup %{conn: conn} do
      event =
        create_event(%{
          "slug" => "aberto",
          "password" => "senha",
          "local" => "Endereço revelado"
        })

      %{conn: unlocked_conn(conn, event.slug), event: event}
    end

    test "shows the location and no unlock form", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      assert html =~ "Endereço revelado"
      refute html =~ "Rolezinho protegido por senha"
      # Join form is visible again
      assert html =~ "id=\"add-main-form\""
    end

    test "can add to the main list without re-entering the password", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> form("#add-main-form", %{"name" => "Alice"})
      |> render_submit()

      assert Events.find(event.slug) |> Map.get(:main_list) |> Enum.at(0) |> Map.get(:name) ==
               "Alice"
    end

    test "raw .txt endpoint includes the location", %{conn: conn, event: event} do
      conn = get(conn, "/r/#{event.slug}.txt")
      assert conn.resp_body =~ "Local: Endereço revelado"
    end

    test "calendar.ics endpoint serves the file with LOCATION", %{conn: conn, event: event} do
      # This event was created without a date, so add one to make .ics valid.
      # update_meta replaces the whole meta block, so re-send `local` too.
      {:ok, _} =
        Rolezinho.Events.update_meta(event, %{
          "local" => event.header |> Rolezinho.Event.Meta.extract() |> elem(0) |> Map.get(:local),
          "date" => "2026-07-15"
        })

      conn = get(conn, "/r/#{event.slug}/calendar.ics")
      assert conn.status == 200
      assert conn.resp_body =~ "LOCATION:Endereço revelado"
    end
  end

  describe "admin sees everything regardless of password" do
    setup %{conn: conn} do
      event = create_event(%{"slug" => "adm", "password" => "s", "local" => "onde"})
      %{conn: admin_conn(conn), event: event}
    end

    test "location visible + no unlock prompt", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      assert html =~ "onde"
      refute html =~ "Rolezinho protegido por senha"
    end
  end
end

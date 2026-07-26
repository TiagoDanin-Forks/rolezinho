defmodule RolezinhoWeb.EventLiveTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp seed_event(attrs \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei",
      "description" => "End: Praia\nHorário: 19h",
      "main_size" => "3",
      "wait_size" => "2"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  describe "public view" do
    setup do
      %{event: seed_event()}
    end

    test "renders title and header", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      assert html =~ "Vôlei"
      assert html =~ "Praia"
    end

    test "still shows individual empty slots on the UI", %{conn: conn, event: event} do
      {:ok, _} = Rolezinho.Events.add_to_main(event, "Alice")

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      # The 2 empty slots are still rendered as their own rows in the UI, since a
      # slot is a position that exists whether or not anyone is in it.
      # The compact "N vagas: URL" summary lives in the shareable text only.
      assert html =~ "Vaga livre"
      # The shareable text (data-text) does have the compact summary.
      assert html =~ "2 vagas: http"
    end

    test "anyone can add themselves to the main list", %{conn: conn, event: event} do
      # Joining goes through a real request: the participant id has to land in
      # the session, and a LiveView cannot write to it.
      post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Alice"})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      assert html =~ "Alice"
    end

    test "anyone can add themselves to the wait list", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> form("#add-wait-form", %{"name" => "Waiter"})
      |> render_submit()

      assert render(view) =~ "Waiter"
    end

    test "anyone can promote wait list to main", %{conn: conn, event: event} do
      # Fill main to leave 2 spots
      {:ok, _} = Events.add_to_main(event, "A")
      event = Events.find(event.slug)
      {:ok, _} = Events.add_to_wait(event, "W1")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> element("button[phx-click=\"promote\"][phx-value-index=\"1\"]")
      |> render_click()

      assert render(view) =~ "W1"
      # No more wait list entries
      refute render(view) =~ "1 pessoa"
    end

    test "does not show admin-only controls when not logged in", %{conn: conn, event: event} do
      {:ok, event} = Events.add_to_main(event, "A")

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      refute html =~ "phx-click=\"toggle_paid_main\""
      refute html =~ "phx-click=\"remove_main\""
      refute html =~ "phx-click=\"grow_main\""
      _ = event
    end
  end

  describe "admin view" do
    setup %{conn: conn} do
      event = seed_event()
      {:ok, event} = Events.add_to_main(event, "Márcia")

      %{conn: admin_conn(conn), event: event}
    end

    test "shows admin controls", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      assert html =~ "phx-click=\"toggle_paid_main\""
      assert html =~ "phx-click=\"grow_main\""
      assert html =~ "Editar"
    end

    test "admin can toggle paid", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> element("button[phx-click=\"toggle_paid_main\"][phx-value-index=\"1\"]")
      |> render_click()

      reloaded = Events.find(event.slug)
      assert Enum.at(reloaded.main_list, 0).paid == true
    end

    test "admin can grow the main list", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> element("button[phx-click=\"grow_main\"]")
      |> render_click()

      reloaded = Events.find(event.slug)
      assert reloaded.main_capacity == event.main_capacity + 1
    end

    test "admin can clone an event and lands on the edit form for the clone", %{
      conn: conn,
      event: event
    } do
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      {:error, {:live_redirect, %{to: to}}} =
        view
        |> element("button[phx-click=\"clone\"]")
        |> render_click()

      assert to == "/admin/r/#{event.slug}-clonado/edit"
      assert Rolezinho.Events.find("#{event.slug}-clonado").title == event.title <> " Clonado"
    end

    test "admin can remove someone and everyone shifts up", %{conn: conn, event: event} do
      {:ok, event} = Events.add_to_main(event, "Bianca")
      {:ok, _event} = Events.add_to_main(event, "Carlos")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> element("button[phx-click=\"remove_main\"][phx-value-index=\"1\"]")
      |> render_click()

      reloaded = Events.find(event.slug)
      names = Enum.map(reloaded.main_list, & &1.name)
      assert names == ["Bianca", "Carlos", ""]
    end
  end

  test "returns to home when the slug does not exist", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/r/nao-existe")
  end

  describe "page title" do
    test "shows filled/total and reserve count in the general case", %{conn: conn} do
      {:ok, event} =
        Rolezinho.Events.create(%{
          "title" => "Meu Evento",
          "slug" => "meu-evento",
          "main_size" => "18",
          "wait_size" => "3"
        })

      # 7 people join the main list
      event =
        Enum.reduce(1..7, event, fn i, ev ->
          {:ok, ev} = Rolezinho.Events.add_to_main(ev, "P#{i}")
          ev
        end)

      # 3 people join the reserve
      _event =
        Enum.reduce(1..3, event, fn i, ev ->
          {:ok, ev} = Rolezinho.Events.add_to_wait(ev, "W#{i}")
          ev
        end)

      {:ok, _view, html} = live(conn, ~p"/r/meu-evento")
      assert html =~ "<title"
      assert html =~ "Meu Evento 7/18 (3 na reserva)"
    end

    test "shows [Cheio] when the main list is full", %{conn: conn} do
      {:ok, event} =
        Rolezinho.Events.create(%{
          "title" => "Outro Evento",
          "slug" => "outro-evento",
          "main_size" => "2",
          "wait_size" => "5"
        })

      {:ok, event} = Rolezinho.Events.add_to_main(event, "A")
      {:ok, event} = Rolezinho.Events.add_to_main(event, "B")

      _event =
        Enum.reduce(1..5, event, fn i, ev ->
          {:ok, ev} = Rolezinho.Events.add_to_wait(ev, "W#{i}")
          ev
        end)

      {:ok, _view, html} = live(conn, ~p"/r/outro-evento")
      assert html =~ "Outro Evento [Cheio] (5 na reserva)"
    end

    test "omits the reserve part when it is empty", %{conn: conn} do
      {:ok, _event} =
        Rolezinho.Events.create(%{
          "title" => "Sem Reserva",
          "slug" => "sem-reserva-title",
          "main_size" => "3",
          "wait_size" => "0"
        })

      {:ok, _view, html} = live(conn, ~p"/r/sem-reserva-title")
      assert html =~ "Sem Reserva 0/3"
      refute html =~ "na reserva"
    end
  end

  describe "pix panel" do
    test "renders a QR code and phone when the description has a Pix key", %{conn: conn} do
      {:ok, _} =
        Rolezinho.Events.create(%{
          "title" => "Com Pix",
          "slug" => "com-pix",
          "description" => "End: Praia\nPix: 91985609019",
          "main_size" => "3",
          "wait_size" => "0"
        })

      {:ok, _view, html} = live(conn, ~p"/r/com-pix")

      assert html =~ "<svg"
      assert html =~ "(91) 98560-9019"
      assert html =~ "Copiar chave"
    end

    test "omits the pix panel when no key is detected", %{conn: conn} do
      {:ok, _} =
        Rolezinho.Events.create(%{
          "title" => "Sem Pix",
          "slug" => "sem-pix",
          "description" => "Só endereço e horário",
          "main_size" => "3",
          "wait_size" => "0"
        })

      {:ok, _view, html} = live(conn, ~p"/r/sem-pix")
      refute html =~ "Copiar chave"
    end
  end
end

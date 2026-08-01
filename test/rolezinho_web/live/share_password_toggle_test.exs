defmodule RolezinhoWeb.SharePasswordToggleTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Event
  alias Rolezinho.Events

  defp create_event(attrs) do
    defaults = %{
      "title" => "T",
      "slug" => "sp",
      "description" => "",
      "local" => "",
      "date" => "",
      "time" => "",
      "main_size" => "3",
      "wait_size" => "0",
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

  describe "to_text :include_password" do
    test "inserts Senha: line right below the URL when the event has a password" do
      event = %Event{
        title: "T",
        password: "abc",
        main_capacity: 1,
        main_list: [%Event.Attendee{}]
      }

      text = Event.to_text(event, "http://roles/t", include_password: true)

      assert String.starts_with?(text, "http://roles/t\nSenha: abc\n\nT")
    end

    test "is a no-op when the event has no password" do
      event = %Event{title: "T", password: nil, main_capacity: 1, main_list: [%Event.Attendee{}]}

      text = Event.to_text(event, "http://roles/t", include_password: true)

      refute text =~ "Senha:"
    end

    test "is off by default even when a password exists" do
      event = %Event{
        title: "T",
        password: "abc",
        main_capacity: 1,
        main_list: [%Event.Attendee{}]
      }

      text = Event.to_text(event, "http://roles/t")

      refute text =~ "Senha:"
    end
  end

  describe "checkbox visibility" do
    test "hidden for anonymous visitors on password-protected events", %{conn: conn} do
      event = create_event(%{"slug" => "anon", "password" => "abc"})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")
      refute html =~ "share-password-toggle"
      refute html =~ "Incluir a senha no texto"
    end

    test "hidden on events without a password", %{conn: conn} do
      event = create_event(%{"slug" => "sempw"})

      {:ok, _view, html} =
        live(
          conn,
          admin_conn(conn) |> then(fn c -> put_in(c.private, %{}) end) && ~p"/r/#{event.slug}"
        )

      # Also check with an admin conn just to make sure it's the "no password" that hides it.
      {:ok, _view, html2} =
        conn
        |> admin_conn()
        |> live(~p"/r/#{event.slug}")

      refute html =~ "share-password-toggle"
      refute html2 =~ "share-password-toggle"
    end

    test "visible for admins on password-protected events", %{conn: conn} do
      event = create_event(%{"slug" => "adm", "password" => "abc"})

      {:ok, _view, html} =
        conn
        |> admin_conn()
        |> live(~p"/r/#{event.slug}")

      assert html =~ "share-password-toggle"
      assert html =~ "Incluir a senha no texto"
    end

    test "visible for unlocked non-admins on password-protected events", %{conn: conn} do
      event = create_event(%{"slug" => "unl", "password" => "abc"})

      {:ok, _view, html} =
        conn
        |> unlocked_conn(event.slug)
        |> live(~p"/r/#{event.slug}")

      assert html =~ "share-password-toggle"
    end
  end

  describe "toggle behavior" do
    setup %{conn: conn} do
      event = create_event(%{"slug" => "toggle", "password" => "s3cret"})
      %{conn: unlocked_conn(conn, event.slug), event: event}
    end

    test "flipping the checkbox includes the password in the share text", %{
      conn: conn,
      event: event
    } do
      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}")

      # Off by default: no Senha in data-text.
      refute html =~ "Senha: s3cret"

      html_after = view |> element("#share-password-toggle") |> render_click()

      assert html_after =~ "Senha: s3cret"

      # Flipping again turns it off.
      html_after_off = view |> element("#share-password-toggle") |> render_click()
      refute html_after_off =~ "Senha: s3cret"
    end
  end

  describe "server-side enforcement" do
    test "unauthorized socket toggle is a no-op (password never leaks)", %{conn: conn} do
      # Event has a password, but visitor's session has no unlock and is not admin.
      event = create_event(%{"slug" => "hacker", "password" => "s3cret"})

      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}")

      refute html =~ "Senha: s3cret"

      # Even though the checkbox isn't rendered, a hacker can still craft a
      # `phx-click` message via the JS console / a custom socket client. We
      # simulate that with `render_hook/3`, which posts a bare event to the LV.
      html_after = render_hook(view, "toggle_share_password")

      refute html_after =~ "Senha: s3cret"
    end

    test "unauthorized socket toggle also cannot flip the flag repeatedly", %{conn: conn} do
      event = create_event(%{"slug" => "hacker2", "password" => "s3cret"})
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      # Fire several toggles in a row; none should stick.
      for _ <- 1..5 do
        html = render_hook(view, "toggle_share_password")
        refute html =~ "Senha: s3cret"
      end
    end

    test "toggle stops working after the password is removed", %{conn: conn} do
      event = create_event(%{"slug" => "cleared", "password" => "s3cret"})
      conn = unlocked_conn(conn, event.slug)

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      # Turn the flag on.
      html = view |> element("#share-password-toggle") |> render_click()
      assert html =~ "Senha: s3cret"

      # Admin clears the password out-of-band; a broadcast :updated arrives.
      {:ok, cleared} = Events.update_password(event, "")

      # The subscribed LV re-renders. The toggle should be hidden and the
      # share text should NOT include the (now-removed) password.
      # Give PubSub a moment to deliver.
      html_after = render(view)
      _ = cleared

      refute html_after =~ "share-password-toggle"
      refute html_after =~ "Senha: s3cret"
    end
  end
end

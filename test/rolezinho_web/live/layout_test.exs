defmodule RolezinhoWeb.LayoutTest do
  @moduledoc """
  The app shell, which is the same on every screen.

  Two of these guard against regressions that are invisible until someone is
  actually on a phone: `vh` puts the bottom of the page under Safari's toolbar,
  and a bottom strip without the safe-area inset sits under the home indicator.
  """
  # async: false — this file now creates an event and drives a LiveView against it.
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "the shell" do
    test "pins the viewport to dvh rather than vh", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "h-dvh"
      refute html =~ "h-screen"
    end

    test "keeps a single column at phone width", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "max-w-[420px]"
    end
  end

  describe "the pinned bottom strip" do
    test "belongs to the screen's action, not to navigation", %{conn: conn} do
      {:ok, event} =
        Rolezinho.Events.create(%{
          "title" => "Vôlei",
          "slug" => "volei-shell-#{System.unique_integer([:positive])}",
          "description" => "End: Praia",
          "main_size" => "4",
          "wait_size" => "0"
        })

      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}")

      # Two destinations do not earn a permanent bar, and the most reachable
      # strip of the screen is worth more to the thing someone came to do.
      refute has_element?(view, ~s{nav[aria-label="Main sections"]})
      assert html =~ "Entrar na lista"
      assert html =~ "env(safe-area-inset-bottom)"
    end

    test "is absent on a screen with no action of its own", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/me")

      refute html =~ "env(safe-area-inset-bottom)"
    end
  end

  describe "reaching settings" do
    test "sits next to the title on the home screen", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, ~s{a[href="/me"][aria-label="Suas preferências"]})
    end
  end

  describe "admin access" do
    test "is offered from settings, since there is no header to hold it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/me")

      assert has_element?(view, ~s{a[href="/admin/login"]})
    end

    test "becomes the panel and a way out once signed in", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:admin?, true)

      {:ok, view, _html} = live(conn, ~p"/me")

      assert has_element?(view, ~s{a[href="/admin"]})
      assert has_element?(view, ~s{a[href="/admin/logout"]})
    end
  end
end

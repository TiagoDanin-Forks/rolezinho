defmodule RolezinhoWeb.LayoutTest do
  @moduledoc """
  The app shell, which is the same on every screen.

  Two of these guard against regressions that are invisible until someone is
  actually on a phone: `vh` puts the bottom of the page under Safari's toolbar,
  and a tab bar without the safe-area inset sits under the home indicator.
  """
  use RolezinhoWeb.ConnCase, async: true

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

    test "clears the home indicator under the tab bar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "env(safe-area-inset-bottom)"
    end
  end

  describe "the tab bar" do
    test "marks the section being viewed", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, ~s{a[aria-current="page"]}, "Rolês")
    end

    test "follows the reader to settings", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/me")

      assert has_element?(view, ~s{a[aria-current="page"]}, "Eu")
    end

    test "stays out of admin screens, which are not a section of the app", %{conn: conn} do
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:admin?, true)

      {:ok, view, _html} = live(conn, ~p"/admin")

      refute has_element?(view, ~s{nav[aria-label="Main sections"]})
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

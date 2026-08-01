defmodule RolezinhoWeb.SettingsLiveTest do
  use RolezinhoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "SettingsLive" do
    test "renders the fields the join sheet reads as defaults", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/me")

      assert has_element?(view, "[data-field=name]")
      assert has_element?(view, "[data-field=phone]")
    end

    test "offers the three theme choices", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/me")

      assert has_element?(view, "[data-theme-option=system]")
      assert has_element?(view, "[data-theme-option=light]")
      assert has_element?(view, "[data-theme-option=dark]")
    end

    test "says plainly that nothing is sent to the server", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/me")

      assert html =~ "Nada disso vai pro servidor"
    end

    test "never renders a value the server does not have", %{conn: conn} do
      # The profile lives in localStorage; the server holds no copy, so the
      # rendered inputs must come back empty regardless of the session.
      {:ok, _view, html} = live(conn, ~p"/me")

      refute html =~ ~s(data-field="name" value=)
      refute html =~ ~s(data-field="phone" value=)
    end

    test "is reachable without joining anything first", %{conn: conn} do
      assert {:ok, _view, _html} = live(conn, ~p"/me")
    end
  end
end

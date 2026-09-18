defmodule RolezinhoWeb.SignedInUITest do
  @moduledoc """
  UI-level checks that the sign-in state actually surfaces on the screens
  people spend time on (home, settings), without breaking anything for
  anonymous visitors.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts

  defp signed_in_conn(conn) do
    {:ok, user} =
      Accounts.find_or_create_by_github(%{
        "github_id" => System.unique_integer([:positive]),
        "github_login" => "some-dev",
        "name" => "Some Dev",
        "avatar_url" => "https://example.com/some-dev.png"
      })

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:current_user_id, user.id)

    %{conn: conn, user: user}
  end

  describe "home page" do
    test "anonymous visitors see the generic user-circle icon and no account chrome",
         %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      # No logout affordance anywhere on the home page — that lives on /me.
      refute html =~ "Sair"
      refute html =~ ~s(href="/auth/logout")

      # The /me link is present and renders the generic icon.
      assert has_element?(view, ~s(a[href="/me"] span.tabler-user-circle))
    end

    test "signed-in visitors: the /me link becomes their avatar (no logout button)",
         %{conn: conn} do
      %{conn: conn} = signed_in_conn(conn)
      {:ok, view, html} = live(conn, ~p"/")

      # The /me link now carries the avatar image, not the generic icon.
      assert has_element?(view, ~s(a[href="/me"] img[src="https://example.com/some-dev.png"]))
      refute has_element?(view, ~s(a[href="/me"] span.tabler-user-circle))

      # Logout deliberately does not live on the navbar anymore; it lives on
      # /me itself. Nothing on the home page should mention it.
      refute html =~ "Sair"
      refute html =~ ~s(href="/auth/logout")
    end
  end

  describe "/me settings page" do
    test "anonymous: shows a quiet invitation to sign in", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/me")
      assert html =~ "Entrar com GitHub"
      # And explicitly reassures the visitor.
      assert html =~ "não precisa de conta"
    end

    test "signed-in: shows the account block with the login handle and a logout button",
         %{conn: conn} do
      %{conn: conn} = signed_in_conn(conn)
      {:ok, _view, html} = live(conn, ~p"/me")

      assert html =~ "@some-dev"
      assert html =~ "Sair"
      refute html =~ "Entrar com GitHub"
    end
  end
end

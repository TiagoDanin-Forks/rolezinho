defmodule RolezinhoWeb.Plugs.UserAdminTest do
  @moduledoc """
  A user whose row has `admin: true` gets `current_admin?` widened on every
  request they authenticate. Complements the environment-wide
  `ADMIN_PASSWORD` session gate — both paths land on the same assign.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Accounts.User
  alias Rolezinho.Repo

  defp create_user(overrides \\ %{}) do
    defaults = %{
      "github_id" => System.unique_integer([:positive]),
      "github_login" => "handle-#{System.unique_integer([:positive])}",
      "name" => nil,
      "email" => nil,
      "avatar_url" => nil
    }

    {:ok, user} = Accounts.find_or_create_by_github(Map.merge(defaults, overrides))
    user
  end

  defp mark_admin(%User{} = user) do
    user
    |> Ecto.Changeset.change(admin: true)
    |> Repo.update!()
  end

  defp signed_in(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
  end

  describe "plug widening" do
    test "a signed-in admin user has current_admin? = true on a plain page", %{conn: conn} do
      user = create_user() |> mark_admin()
      conn = signed_in(conn, user) |> get(~p"/")

      assert conn.assigns.current_admin? == true
    end

    test "a signed-in non-admin user does NOT have current_admin? widened", %{conn: conn} do
      user = create_user()
      conn = signed_in(conn, user) |> get(~p"/")

      assert conn.assigns.current_admin? == false
    end

    test "an anonymous request still has current_admin? = false", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert conn.assigns.current_admin? == false
    end
  end

  describe "LiveView widening (on_mount)" do
    test "a signed-in admin user sees admin-only affordances on the home LiveView",
         %{conn: conn} do
      # The presence of `current_admin?` is enough \u2014 we don't hardcode a
      # specific admin element here to avoid pinning the test to a shifting
      # UI; the plug/on_mount contract is what we're locking down.
      user = create_user() |> mark_admin()
      conn = signed_in(conn, user)

      {:ok, view, _html} = live(conn, ~p"/")

      # The Admin plug's on_mount seeds current_admin? from the session; the\n      # User on_mount raises it based on user.admin. The composed value must
      # end up true here, mirroring the plug pipeline used for HTTP.
      state = :sys.get_state(view.pid)
      assert state.socket.assigns.current_admin? == true
    end

    test "a signed-in non-admin user does NOT get current_admin? widened on the LiveView",
         %{conn: conn} do
      user = create_user()
      conn = signed_in(conn, user)

      {:ok, view, _html} = live(conn, ~p"/")

      state = :sys.get_state(view.pid)
      assert state.socket.assigns.current_admin? == false
    end
  end

  describe "mass-assignment protection" do
    test "github_changeset never casts :admin, even if attrs include it" do
      # A hostile OAuth response (or a bug that reuses this changeset for a
      # form) must not be able to promote a user to admin.
      user = create_user()

      {:ok, refreshed} =
        Accounts.find_or_create_by_github(%{
          "github_id" => user.github_id,
          "github_login" => user.github_login,
          "admin" => true
        })

      assert refreshed.admin == false
    end
  end
end

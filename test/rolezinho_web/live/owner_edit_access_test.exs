defmodule RolezinhoWeb.OwnerEditAccessTest do
  @moduledoc """
  The role/group owner is not the platform admin. This exercises the
  fix that broadened the three edit surfaces off the admin password:

    * `/admin/r/:slug/edit` (EventEditLive)
    * `/admin/r/:slug/formulario` (FormConfigLive)
    * `/admin/g/:slug/edit` (GroupEditLive)

  Each opens for the resource's own owner via `Policy.can_edit?/2`
  (event) or `Group.editable_by?/4` (group), and each hides the
  admin-only sub-controls (owner reassignment, group move, delete;
  group visibility + delete) behind `:if={@current_admin?}`.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Events
  alias Rolezinho.Groups

  defp new_user!(login) do
    {:ok, user} =
      Accounts.find_or_create_by_github(%{
        "github_id" => System.unique_integer([:positive]),
        "github_login" => login
      })

    user
  end

  defp signed_in(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  defp create_event(overrides, opts) do
    defaults = %{
      "title" => "Rolê",
      "slug" => "e-#{System.unique_integer([:positive])}",
      "main_size" => "3",
      "wait_size" => "0"
    }

    {:ok, event} = Events.create(Map.merge(defaults, overrides), opts)
    event
  end

  describe "EventEditLive (/admin/r/:slug/edit)" do
    test "the event's creator (signed in) can open the edit page without the admin password",
         %{conn: conn} do
      user = new_user!("owner-edit-1")
      event = create_event(%{}, admin?: false, created_by_user_id: user.id)

      conn = signed_in(conn, user)
      {:ok, _view, html} = live(conn, ~p"/admin/r/#{event.slug}/edit")

      assert html =~ "Editar"
    end

    test "a stranger is redirected back to the event page", %{conn: conn} do
      owner = new_user!("owner-edit-stranger")
      stranger = new_user!("stranger")
      event = create_event(%{}, admin?: false, created_by_user_id: owner.id)

      conn = signed_in(conn, stranger)

      assert {:error, {:live_redirect, %{to: to}}} =
               live(conn, ~p"/admin/r/#{event.slug}/edit")

      assert to == "/r/#{event.slug}"
    end

    test "owner sees the details section but NOT the admin-only Delete/Owner/Group panels",
         %{conn: conn} do
      user = new_user!("owner-edit-panels")
      event = create_event(%{}, admin?: false, created_by_user_id: user.id)

      {:ok, view, html} = live(signed_in(conn, user), ~p"/admin/r/#{event.slug}/edit")

      # Details form is there.
      assert has_element?(view, "form#details-form")

      # Admin-only sections are gone from the DOM.
      refute has_element?(view, "form#creator-form")
      refute has_element?(view, "form#group-form")
      refute html =~ "Zona perigosa"
    end

    test "admin sees the admin-only panels", %{conn: conn} do
      event = create_event(%{}, admin?: true)

      {:ok, view, html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      assert has_element?(view, "form#creator-form")
      assert has_element?(view, "form#group-form")
      assert html =~ "Zona perigosa"
    end
  end

  describe "FormConfigLive (/admin/r/:slug/formulario)" do
    test "the event's creator can open it", %{conn: conn} do
      user = new_user!("owner-form-1")
      event = create_event(%{}, admin?: false, created_by_user_id: user.id)

      {:ok, _view, html} = live(signed_in(conn, user), ~p"/admin/r/#{event.slug}/formulario")

      assert html =~ "Formulário"
    end

    test "a stranger is redirected to the event page", %{conn: conn} do
      owner = new_user!("owner-form-stranger")
      stranger = new_user!("stranger-form")
      event = create_event(%{}, admin?: false, created_by_user_id: owner.id)

      assert {:error, {:live_redirect, %{to: to}}} =
               live(signed_in(conn, stranger), ~p"/admin/r/#{event.slug}/formulario")

      assert to == "/r/#{event.slug}"
    end
  end

  describe "GroupEditLive (/admin/g/:slug/edit)" do
    defp create_group(overrides \\ %{}) do
      defaults = %{
        "name" => "Grupo",
        "slug" => "g-#{System.unique_integer([:positive])}"
      }

      {:ok, group} = Groups.create(Map.merge(defaults, overrides))
      group
    end

    test "the group's signed-in creator can open the edit page", %{conn: conn} do
      user = new_user!("owner-group-1")

      {:ok, group} =
        Groups.create(
          %{"name" => "Meu Grupo", "slug" => "gowner-#{System.unique_integer([:positive])}"},
          created_by_user_id: user.id
        )

      {:ok, _view, html} = live(signed_in(conn, user), ~p"/admin/g/#{group.slug}/edit")

      assert html =~ "Editar"
    end

    test "owner does NOT see the visibility toggle nor delete panel", %{conn: conn} do
      user = new_user!("owner-group-panels")

      {:ok, group} =
        Groups.create(
          %{"name" => "Meu Grupo", "slug" => "gp-#{System.unique_integer([:positive])}"},
          created_by_user_id: user.id
        )

      {:ok, _view, html} = live(signed_in(conn, user), ~p"/admin/g/#{group.slug}/edit")

      refute html =~ "Visibilidade"
      refute html =~ "Zona perigosa"
    end

    test "admin sees the visibility toggle and delete panel", %{conn: conn} do
      group = create_group()

      {:ok, _view, html} = live(admin_conn(conn), ~p"/admin/g/#{group.slug}/edit")

      assert html =~ "Visibilidade"
      assert html =~ "Zona perigosa"
    end
  end

  describe "user.admin: true grants admin capability on admin-required routes" do
    test "user flagged admin can reach /admin without the shared password", %{conn: conn} do
      user = new_user!("flag-admin-1") |> mark_admin()

      {:ok, _view, html} = live(signed_in(conn, user), ~p"/admin")

      assert html =~ "Painel"
    end

    defp mark_admin(%Accounts.User{} = user) do
      user
      |> Ecto.Changeset.change(admin: true)
      |> Rolezinho.Repo.update!()
    end
  end
end

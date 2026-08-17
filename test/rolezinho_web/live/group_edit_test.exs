defmodule RolezinhoWeb.GroupEditTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events
  alias Rolezinho.Groups

  defp create_group(overrides \\ %{}) do
    defaults = %{"name" => "Vôlei", "slug" => "vlei", "visibility" => "public"}
    {:ok, group} = Groups.create(Map.merge(defaults, overrides))
    group
  end

  defp create_event(group_id, overrides) do
    defaults = %{
      "title" => "Rolê",
      "slug" => "role-#{System.unique_integer([:positive])}",
      "description" => "",
      "local" => "",
      "date" => "",
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

  describe "authorization" do
    test "non-admin cannot reach the edit page", %{conn: conn} do
      group = create_group()
      # No admin session → redirect to /admin/login.
      conn = get(conn, ~p"/admin/g/#{group.slug}/edit")
      assert redirected_to(conn) =~ "/admin/login"
    end

    test "admin can reach it", %{conn: conn} do
      group = create_group()
      {:ok, _view, html} = live(admin_conn(conn), ~p"/admin/g/#{group.slug}/edit")
      assert html =~ "Editar grupo"
    end
  end

  describe "admin can edit passwordless group" do
    setup %{conn: conn} do
      group = create_group(%{"slug" => "sem-senha"})
      %{conn: admin_conn(conn), group: group}
    end

    test "renames the group", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/admin/g/#{group.slug}/edit")
      render_submit(view, "save_name", %{"name" => "Renomeado"})
      assert Groups.find(group.slug).name == "Renomeado"
    end

    test "sets a password", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/admin/g/#{group.slug}/edit")
      render_submit(view, "save_password", %{"password" => "s3cret"})
      assert Groups.find(group.slug).password == "s3cret"
    end

    test "flips visibility to hidden", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/admin/g/#{group.slug}/edit")
      render_click(view, "set_visibility", %{"visibility" => "hidden"})
      assert Groups.find(group.slug).visibility == :hidden
    end
  end

  describe "delete cascades to events (hides them)" do
    test "delete marks the group's active events hidden", %{conn: conn} do
      group = create_group(%{"slug" => "kill-me"})
      event = create_event(group.id, %{})

      {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/g/#{group.slug}/edit")
      render_click(view, "delete")

      # Group is gone.
      refute Groups.find("kill-me")

      # Event survives but is hidden and un-grouped.
      reloaded = Events.find(event.slug)
      assert reloaded.status == :hidden
      assert reloaded.group_id == nil
    end
  end

  describe "admin moves events between groups" do
    test "the group select on the event edit page changes group_id", %{conn: conn} do
      group_a = create_group(%{"slug" => "ga", "name" => "Grupo A"})
      group_b = create_group(%{"slug" => "gb", "name" => "Grupo B"})
      event = create_event(group_a.id, %{})

      {:ok, view, html} = live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")
      # The select carries both groups + Nenhum.
      assert has_element?(view, "#event-group-select option[value='']")
      assert html =~ "/g/ga"
      assert html =~ "/g/gb"

      # Move to B via phx-change on the form.
      render_change(view, "set_group", %{"group_id" => Integer.to_string(group_b.id)})
      assert Events.find(event.slug).group_id == group_b.id

      # Remove from any group.
      render_change(view, "set_group", %{"group_id" => ""})
      assert is_nil(Events.find(event.slug).group_id)
    end
  end
end

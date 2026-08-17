defmodule RolezinhoWeb.GroupLiveTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events
  alias Rolezinho.Groups

  defp create_group(overrides \\ %{}) do
    defaults = %{"name" => "Vôlei do Bairro", "slug" => "vb", "visibility" => "public"}
    {:ok, group} = Groups.create(Map.merge(defaults, overrides))
    group
  end

  defp create_event(group, overrides) do
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
      Events.create(Map.merge(defaults, overrides), admin?: true, group_id: group.id)

    event
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  defp unlocked_group_conn(conn, slug) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:unlocked_groups, MapSet.new([slug]))
  end

  describe "public passwordless group" do
    setup do
      group = create_group(%{"slug" => "aberto", "name" => "Aberto"})
      event = create_event(group, %{"title" => "Segunda 19h", "slug" => "seg-19"})
      %{group: group, event: event}
    end

    test "shows the group name and lists its events", %{conn: conn, group: group} do
      {:ok, _view, html} = live(conn, ~p"/g/#{group.slug}")
      assert html =~ "Aberto"
      assert html =~ "Segunda 19h"
    end

    test "anonymous visitor sees a hint that only admin can edit", %{conn: conn, group: group} do
      {:ok, _view, html} = live(conn, ~p"/g/#{group.slug}")
      assert html =~ "só o admin"
      refute html =~ "Novo rolê"
    end

    test "no inline edit form is rendered", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/g/#{group.slug}")
      refute has_element?(view, "#group-name-form")
    end
  end

  describe "hidden passwordless group" do
    setup do
      group =
        create_group(%{"slug" => "occulto-uno", "visibility" => "hidden", "name" => "Ocultão"})

      %{group: group}
    end

    test "is not on the public home", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      refute html =~ "Ocultão"
    end

    test "is reachable by direct URL", %{conn: conn, group: group} do
      {:ok, _view, html} = live(conn, ~p"/g/#{group.slug}")
      assert html =~ "Ocultão"
    end
  end

  describe "password-protected group (locked)" do
    setup do
      group =
        create_group(%{"slug" => "trancado", "password" => "senha123", "name" => "Segredo"})

      # Event listed inside so we can prove it doesn't leak while locked.
      event = create_event(group, %{"title" => "Rolê Secreto", "slug" => "secreto-1"})
      %{group: group, event: event}
    end

    test "renders only the unlock panel — no group name, no event titles", %{
      conn: conn,
      group: group
    } do
      {:ok, view, html} = live(conn, ~p"/g/#{group.slug}")

      # The name and the events must not reach the HTML at all.
      refute html =~ "Segredo"
      refute html =~ "Rolê Secreto"
      # The slug alone would be too much of a leak, given the page URL is the
      # slug itself, so we don't assert on absence of it — but the unlock form
      # must be present.
      assert has_element?(view, "#group-unlock-form-#{group.slug}")
      assert html =~ "protegido por senha"
    end

    test "page title does not leak the group name", %{conn: conn, group: group} do
      {:ok, _view, html} = live(conn, ~p"/g/#{group.slug}")
      # `page_title_for` masks it — the tab title reads a generic phrase.
      refute html =~ "<title>Segredo"
      assert html =~ "Grupo protegido"
    end

    test "password itself never lands in the DOM", %{conn: conn, group: group} do
      {:ok, _view, html} = live(conn, ~p"/g/#{group.slug}")
      refute html =~ "senha123"
    end
  end

  describe "unlock flow via POST /g/:slug/unlock" do
    setup do
      group = create_group(%{"slug" => "abrir", "password" => "abc"})
      %{group: group}
    end

    test "wrong password stays locked", %{conn: conn, group: group} do
      conn = post(conn, ~p"/g/#{group.slug}/unlock", %{"password" => "errada"})
      assert redirected_to(conn) == "/g/#{group.slug}"
      refute Plug.Conn.get_session(conn, :unlocked_groups) |> is_map()
    end

    test "right password unlocks the session for this slug", %{conn: conn, group: group} do
      conn = post(conn, ~p"/g/#{group.slug}/unlock", %{"password" => "abc"})
      assert redirected_to(conn) == "/g/#{group.slug}"

      unlocked = Plug.Conn.get_session(conn, :unlocked_groups)
      assert MapSet.member?(unlocked, group.slug)
    end
  end

  describe "password-protected group (unlocked)" do
    setup %{conn: conn} do
      group = create_group(%{"slug" => "aberto2", "password" => "s", "name" => "Aberto"})
      event = create_event(group, %{"title" => "Rolê Aberto", "slug" => "aberto-1"})

      %{conn: unlocked_group_conn(conn, group.slug), group: group, event: event}
    end

    test "shows name + events + inline edit forms", %{conn: conn, group: group} do
      {:ok, view, html} = live(conn, ~p"/g/#{group.slug}")
      assert html =~ "Aberto"
      assert html =~ "Rolê Aberto"
      assert has_element?(view, "#group-name-form")
      assert has_element?(view, "#group-password-form")
      # And the "Novo rolê" navigation into a group-scoped creation.
      assert html =~ "Novo rolê"
    end

    test "editing the name via socket updates the group", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/g/#{group.slug}")

      # Trigger the name save.
      render_submit(view, "save_name", %{"name" => "Novo nome"})

      assert Groups.find(group.slug).name == "Novo nome"
    end

    test "clearing password removes protection", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/g/#{group.slug}")
      render_submit(view, "save_password", %{"password" => ""})

      refute Rolezinho.Group.password_protected?(Groups.find(group.slug))
    end
  end

  describe "admin bypass" do
    setup %{conn: conn} do
      group = create_group(%{"slug" => "adm", "password" => "s", "name" => "Fechado"})
      %{conn: admin_conn(conn), group: group}
    end

    test "admin sees everything without unlocking", %{conn: conn, group: group} do
      {:ok, view, html} = live(conn, ~p"/g/#{group.slug}")
      assert html =~ "Fechado"
      refute has_element?(view, "#group-unlock-form-#{group.slug}")
      # Admin gets the settings shortcut in the header.
      assert has_element?(view, "a[href='/admin/g/#{group.slug}/edit']")
    end
  end

  describe "hidden events inside a group" do
    setup do
      group = create_group()
      # Create as admin so the event starts active, then set hidden.
      event = create_event(group, %{"title" => "Ver-me se souber", "slug" => "hidden-role"})
      {:ok, event} = Events.set_status(event, :hidden)
      %{group: group, event: event}
    end

    test "are not listed on the group page even to admin", %{conn: conn, group: group} do
      {:ok, _view, html} = live(admin_conn(conn), ~p"/g/#{group.slug}")
      refute html =~ "Ver-me se souber"
    end
  end
end

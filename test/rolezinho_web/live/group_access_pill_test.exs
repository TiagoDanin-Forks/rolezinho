defmodule RolezinhoWeb.GroupAccessPillTest do
  @moduledoc """
  A password-protected group carries a live status pill for the current
  viewer: neutral "com senha" when they cannot open it, success-toned
  "com acesso" when they can (admin, creator, or session-unlocked).

  This is a small copy tweak but it's the only place on the home listing
  and on the group header that reflects the viewer's own state, so the
  render paths are worth locking down with tests.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Groups

  defp new_user!(login) do
    {:ok, user} =
      Accounts.find_or_create_by_github(%{
        "github_id" => System.unique_integer([:positive]),
        "github_login" => login
      })

    user
  end

  defp signed_in_conn(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
  end

  defp create_locked_group(overrides) do
    defaults = %{
      "name" => "Fechado",
      "slug" => "closed-#{System.unique_integer([:positive])}",
      "password" => "s3nh4",
      "visibility" => "public"
    }

    {:ok, group} = Groups.create(Map.merge(defaults, overrides))
    group
  end

  describe "home listing pill" do
    test "stranger sees 'com senha' (neutral) on a locked group", %{conn: conn} do
      _group = create_locked_group(%{"slug" => "loc-strange", "name" => "Bloqueado"})

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "· com senha"
      refute html =~ "· com acesso"
    end

    test "signed-in creator sees 'com acesso' (success tone) on their own locked group",
         %{conn: conn} do
      user = new_user!("gh-creator")

      # Creator is set on insert via the LiveView; here we do it directly.
      {:ok, group} =
        Groups.create(%{
          "name" => "Meu grupo",
          "slug" => "loc-creator",
          "password" => "s3nh4",
          "visibility" => "public"
        })

      {:ok, group} =
        group
        |> Rolezinho.Group.put_created_by_user_id(user.id)
        |> Rolezinho.Repo.update()

      assert group.created_by_user_id == user.id

      conn = signed_in_conn(conn, user)
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "· com acesso"
      refute html =~ "· com senha"
    end
  end

  describe "group header pill" do
    test "renders 'Com acesso' with success tone when the viewer can see the contents",
         %{conn: conn} do
      # An admin session gets past the gate on any group, which is the
      # cheapest path to render the header without going through the
      # unlock POST.
      group = create_locked_group(%{"slug" => "loc-admin", "name" => "Admin Land"})

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:admin?, true)

      {:ok, _view, html} = live(conn, ~p"/g/#{group.slug}")

      assert html =~ "Com acesso"
      refute html =~ ">Com senha<"
    end
  end
end

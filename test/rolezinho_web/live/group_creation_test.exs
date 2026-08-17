defmodule RolezinhoWeb.GroupCreationTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Group
  alias Rolezinho.Groups

  describe "GroupNewLive form" do
    test "renders the create form and the password-consequence hint", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/g/criar")

      assert has_element?(view, "#new-group-form")
      assert has_element?(view, "input[name='group[name]']")
      assert has_element?(view, "input[name='group[slug]']")
      # The explanation of the password rule has to be inline on the form,
      # before the "Criar" button, so someone reads it before they submit.
      assert html =~ "só o admin da plataforma consegue editar"
    end
  end

  describe "POST /g/criar" do
    test "creates a passwordless group and redirects to it", %{conn: conn} do
      conn =
        post(conn, ~p"/g/criar", %{
          "group" => %{
            "name" => "Aberto pra todos",
            "slug" => "abertos",
            "password" => "",
            "visibility" => "public"
          }
        })

      assert redirected_to(conn) == "/g/abertos"

      # The user sees the "only admin can edit" reminder they were nudged about.
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "só o admin"

      # And the group exists as public + passwordless.
      group = Groups.find("abertos")
      assert group
      assert group.visibility == :public
      refute Group.password_protected?(group)
    end

    test "creates a password-protected group and auto-unlocks it in session", %{conn: conn} do
      conn =
        post(conn, ~p"/g/criar", %{
          "group" => %{
            "name" => "Fechado",
            "slug" => "fechado",
            "password" => "s3nh4",
            "visibility" => "public"
          }
        })

      assert redirected_to(conn) == "/g/fechado"
      # The session must remember the unlock so the creator lands on the group
      # page and sees the group they just made, not an unlock gate.
      unlocked = Plug.Conn.get_session(conn, :unlocked_groups)
      assert MapSet.member?(unlocked, "fechado")

      # The success flash points at the password as the way back in.
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "senha"
    end

    test "invalid params come back to the form with an error flash", %{conn: conn} do
      conn =
        post(conn, ~p"/g/criar", %{
          "group" => %{
            "name" => "",
            "slug" => "",
            "password" => "",
            "visibility" => "public"
          }
        })

      assert redirected_to(conn) == "/g/criar"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "hidden groups do not appear on the home listing", %{conn: conn} do
      _hidden =
        post(conn, ~p"/g/criar", %{
          "group" => %{
            "name" => "Oculto",
            "slug" => "oculto1",
            "password" => "",
            "visibility" => "hidden"
          }
        })

      {:ok, _view, html} = live(conn, ~p"/")
      refute html =~ "Oculto"

      # But direct URL still works.
      {:ok, _view2, html2} = live(conn, ~p"/g/oculto1")
      assert html2 =~ "Oculto"
    end
  end
end

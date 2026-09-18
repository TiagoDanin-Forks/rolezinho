defmodule RolezinhoWeb.GroupCreationTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Group
  alias Rolezinho.Groups

  # A signed-in test conn — the minimum required to get past the ADR-0002
  # creation gate without going through the OAuth flow.
  defp signed_in_conn(conn, attrs \\ %{}) do
    defaults = %{
      "github_id" => System.unique_integer([:positive]),
      "github_login" => "gh-user",
      "name" => "Ghost User",
      "email" => nil,
      "avatar_url" => nil
    }

    {:ok, user} = Accounts.find_or_create_by_github(Map.merge(defaults, attrs))

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:current_user_id, user.id)

    %{conn: conn, user: user}
  end

  describe "gate: anonymous visitors are redirected to /entrar" do
    test "GET /g/criar (LiveView) redirects", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: to}}} = live(conn, ~p"/g/criar")
      assert String.starts_with?(to, "/entrar")
    end

    test "POST /g/criar redirects and does not create anything", %{conn: conn} do
      conn =
        post(conn, ~p"/g/criar", %{
          "group" => %{"name" => "Nope", "slug" => "nope-1"}
        })

      assert redirected_to(conn) =~ "/entrar"
      assert Groups.find("nope-1") == nil
    end
  end

  describe "GroupNewLive form (signed in)" do
    test "renders the create form and the password-consequence hint", %{conn: conn} do
      %{conn: conn} = signed_in_conn(conn)
      {:ok, view, html} = live(conn, ~p"/g/criar")

      assert has_element?(view, "#new-group-form")
      assert has_element?(view, "input[name='group[name]']")
      assert has_element?(view, "input[name='group[slug]']")
      # The explanation of the password rule has to be inline on the form,
      # before the "Criar" button, so someone reads it before they submit.
      assert html =~ "só o admin da plataforma consegue editar"
    end
  end

  describe "POST /g/criar (signed in)" do
    test "creates a passwordless group with the signed-in user as its creator",
         %{conn: conn} do
      %{conn: conn, user: user} = signed_in_conn(conn)

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

      # Under ADR-0002 the flash reflects that the creator can manage the
      # group even without a password, because they own it.
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "gerencia"

      group = Groups.find("abertos")
      assert group
      assert group.visibility == :public
      refute Group.password_protected?(group)
      assert group.created_by_user_id == user.id
    end

    test "creates a password-protected group and auto-unlocks it in session", %{conn: conn} do
      %{conn: conn} = signed_in_conn(conn)

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
      unlocked = Plug.Conn.get_session(conn, :unlocked_groups)
      assert MapSet.member?(unlocked, "fechado")

      # The success flash points at the password as the way back in.
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "senha"
    end

    test "invalid params come back to the form with an error flash", %{conn: conn} do
      %{conn: conn} = signed_in_conn(conn)

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
      %{conn: conn} = signed_in_conn(conn)

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

  describe "signed-in creator retains edit rights over their group" do
    test "even without a password and without the group unlock", %{conn: conn} do
      %{conn: conn, user: user} = signed_in_conn(conn)

      # Create the group.
      conn =
        post(conn, ~p"/g/criar", %{
          "group" => %{
            "name" => "Sem senha e meu",
            "slug" => "meu-grupo",
            "password" => "",
            "visibility" => "public"
          }
        })

      assert redirected_to(conn) == "/g/meu-grupo"
      group = Groups.find("meu-grupo")
      assert group.created_by_user_id == user.id

      # And the durable-owner rule applies without a password unlock.
      refute Group.password_protected?(group)
      assert Group.editable_by?(group, false, MapSet.new(), user.id)
      # Meanwhile, a different signed-in user cannot edit it.
      refute Group.editable_by?(group, false, MapSet.new(), user.id + 999)
    end
  end
end

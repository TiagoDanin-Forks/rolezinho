defmodule RolezinhoWeb.EventEditSlugTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  defp seed do
    {:ok, event} =
      Events.create(%{
        "title" => "T",
        "slug" => "antigo",
        "main_size" => "3",
        "wait_size" => "0"
      })

    event
  end

  test "admin can rename the slug via the edit form", %{conn: conn} do
    _event = seed()

    {:ok, view, _html} =
      conn
      |> admin_conn()
      |> live(~p"/admin/r/antigo/edit")

    {:error, {:live_redirect, %{to: to}}} =
      view
      |> form("#slug-form", %{"slug" => "novo"})
      |> render_submit()

    assert to == "/admin/r/novo/edit"
    assert Events.find("novo").title == "T"
    assert Events.find("antigo") == nil
  end

  test "shows an error and stays on the same page when the slug is taken", %{conn: conn} do
    _event = seed()

    {:ok, _} =
      Events.create(%{
        "title" => "Outro",
        "slug" => "tomado",
        "main_size" => "1",
        "wait_size" => "0"
      })

    {:ok, view, _html} =
      conn
      |> admin_conn()
      |> live(~p"/admin/r/antigo/edit")

    html =
      view
      |> form("#slug-form", %{"slug" => "tomado"})
      |> render_submit()

    assert html =~ "já está em uso"
    # File was not moved
    assert Events.find("antigo").title == "T"
  end

  test "shows an error for malformed slugs", %{conn: conn} do
    _event = seed()

    {:ok, view, _html} =
      conn
      |> admin_conn()
      |> live(~p"/admin/r/antigo/edit")

    # Bypass HTML5 pattern validation by submitting the form directly.
    html = render_submit(form(view, "#slug-form"), %{"slug" => "não vale"})

    assert html =~ "Slug inválido"
    assert Events.find("antigo").title == "T"
  end
end

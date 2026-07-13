defmodule RolezinhoWeb.PageControllerTest do
  use RolezinhoWeb.ConnCase, async: false

  test "GET / renders the rolezinhos home", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Rolezinhos"
  end
end

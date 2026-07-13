defmodule RolezinhoWeb.RawControllerTest do
  use RolezinhoWeb.ConnCase, async: false

  alias Rolezinho.Events

  test "serves plain text via .txt suffix", %{conn: conn} do
    {:ok, event} =
      Events.create(%{
        "title" => "Vôlei",
        "slug" => "volei",
        "description" => "End: Praia\nHorário: 19h",
        "main_size" => "3",
        "wait_size" => "0"
      })

    {:ok, _} = Events.add_to_main(event, "Alice")

    conn = get(conn, "/r/volei.txt")
    assert conn.status == 200
    text = conn.resp_body
    assert text =~ "Vôlei"
    assert text =~ "1- Alice"
    refute String.starts_with?(text, "#")
  end

  test "returns 404 for missing slug", %{conn: conn} do
    conn = get(conn, "/r/nada.txt")
    assert conn.status == 404
  end

  test "hides done events from public raw endpoint", %{conn: conn} do
    {:ok, event} =
      Events.create(%{
        "title" => "Antigo",
        "slug" => "antigo",
        "main_size" => "1",
        "wait_size" => "0"
      })

    {:ok, _} = Events.set_status(event, :done)

    conn = get(conn, "/r/antigo.txt")
    assert conn.status == 404
  end
end

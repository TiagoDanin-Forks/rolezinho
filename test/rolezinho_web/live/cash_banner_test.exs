defmodule RolezinhoWeb.CashBannerTest do
  @moduledoc """
  RN-15 on the event page.

  What the group still owes is the organizer's problem to chase — they are the
  one who paid the court up front. It is not a scoreboard for everyone else,
  which is why the banner is scoped rather than public.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp seed(attrs \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei-cash-#{System.unique_integer([:positive])}",
      "description" => "End: Praia",
      "main_size" => "4",
      "wait_size" => "0",
      "price" => "R$ 15",
      "pix_key" => "91984933238"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    {:ok, event} = Events.add_to_main(event, "Marcia", participant_id: "a")
    {:ok, event} = Events.add_to_main(event, "Roberta", participant_id: "b")
    {:ok, event} = Events.toggle_paid_main(event, 1)
    event
  end

  defp as_admin(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  describe "the outstanding banner" do
    test "shows the organizer what is missing and who owes", %{conn: conn} do
      event = seed()

      {:ok, _view, html} = live(as_admin(conn), ~p"/r/#{event.slug}")

      assert html =~ "Falta R$ 15"
      assert html =~ "1 pessoa não pagou"
    end

    test "offers one message addressed to everyone who owes", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(as_admin(conn), ~p"/r/#{event.slug}")

      assert has_element?(view, ~s{a[href^="https://wa.me/?text="]})
      assert render(view) =~ "Cobrar no WhatsApp"
    end

    test "counts several debtors in one message", %{conn: conn} do
      event = seed()
      {:ok, _} = Events.add_to_main(event, "Henrique", participant_id: "c")

      {:ok, _view, html} = live(as_admin(conn), ~p"/r/#{event.slug}")

      assert html =~ "Faltam R$ 30"
      assert html =~ "2 pessoas não pagaram"
      assert html =~ "Cobrar os 2 no WhatsApp"
    end

    test "stays hidden from a plain visitor", %{conn: conn} do
      event = seed()

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      refute html =~ "não pagou o Pix"
      refute html =~ "Cobrar"
    end

    test "stays hidden from someone who merely joined", %{conn: conn} do
      event = seed()
      conn = post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Bruno"})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      refute html =~ "Cobrar"
    end

    test "disappears once everybody has declared payment", %{conn: conn} do
      event = seed()
      {:ok, _} = Events.toggle_paid_main(event, 2)

      {:ok, _view, html} = live(as_admin(conn), ~p"/r/#{event.slug}")

      refute html =~ "Cobrar"
    end

    test "never appears for a free event", %{conn: conn} do
      event = seed(%{"price" => ""})

      {:ok, _view, html} = live(as_admin(conn), ~p"/r/#{event.slug}")

      refute html =~ "Cobrar"
    end
  end
end

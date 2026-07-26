defmodule RolezinhoWeb.ListScreenTest do
  @moduledoc """
  What the list screen shows, from the perspective of whoever is reading it.

  The distinction that matters here: a check someone cannot flip must still be
  *visible*. Whether Marcia paid is information for the whole group, not a
  control reserved for whoever can change it.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp seed do
    {:ok, event} =
      Events.create(%{
        "title" => "Cowork",
        "slug" => "cowork-list",
        "description" => "End: Batista Campos",
        "main_size" => "4",
        "wait_size" => "0"
      })

    {:ok, event} = Events.add_to_main(event, "Ana", participant_id: "someone-else")
    event
  end

  defp join_as(conn, slug, name) do
    post(conn, ~p"/r/#{slug}/join", %{"name" => name})
  end

  describe "the payment legend (RN-14)" do
    test "is always above the list", %{conn: conn} do
      event = seed()

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "já pagou o Pix"
      assert html =~ "ainda não pagou"
    end
  end

  describe "checks" do
    test "somebody else's check is visible but not interactive", %{conn: conn} do
      event = seed()
      {:ok, _} = Events.toggle_paid_main(event, 1)

      conn = join_as(conn, event.slug, "Bruno")
      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}")

      # Rendered as an image role: it reports state, it does not accept a tap.
      assert html =~ ~s(aria-label="Paid")
      refute has_element?(view, ~s{button[aria-label="Mark as unpaid"][phx-value-index="1"]})
    end

    test "my own check is interactive", %{conn: conn} do
      event = seed()

      conn = join_as(conn, event.slug, "Bruno")
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      assert has_element?(view, ~s{button[aria-label="Mark as paid"][phx-value-index="2"]})
    end

    test "a visitor who joined nothing sees state but no controls", %{conn: conn} do
      event = seed()

      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ ~s(aria-label="Not paid yet")
      refute has_element?(view, ~s{button[aria-label="Mark as paid"]})
    end
  end

  describe "leaving" do
    test "I can leave, and the prompt says so plainly", %{conn: conn} do
      event = seed()

      conn = join_as(conn, event.slug, "Bruno")
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      assert has_element?(view, ~s{button[aria-label="Sair da lista"]})
      assert has_element?(view, ~s{button[data-confirm="Sair da lista?"]})
    end

    test "I cannot remove somebody else", %{conn: conn} do
      event = seed()

      conn = join_as(conn, event.slug, "Bruno")
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      refute has_element?(view, ~s{button[aria-label="Remover Ana"]})
    end

    test "the organizer names who is being removed (RN-22)", %{conn: conn} do
      event = seed()

      admin =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:admin?, true)

      {:ok, view, _html} = live(admin, ~p"/r/#{event.slug}")

      assert has_element?(view, ~s{button[data-confirm="Remover Ana da lista?"]})
    end
  end

  describe "the coachmark" do
    test "appears only once the reader has a row of their own", %{conn: conn} do
      event = seed()

      {:ok, _view, before_joining} = live(conn, ~p"/r/#{event.slug}")
      refute before_joining =~ "Toque no check"

      conn = join_as(conn, event.slug, "Bruno")
      {:ok, _view, after_joining} = live(conn, ~p"/r/#{event.slug}")
      assert after_joining =~ "Toque no check"
    end
  end

  describe "empty slots" do
    test "are rendered as rows, since a slot is a position", %{conn: conn} do
      event = seed()

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "Vaga livre"
    end
  end
end

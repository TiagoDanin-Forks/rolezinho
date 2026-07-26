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

  describe "what the check means (RN-14)" do
    test "the count next to the list says it", %{conn: conn} do
      # A check cannot stand alone, and the count is what explains it: read the
      # number and the marks below it tell the same story. A legend of
      # circle-plus-label pairs said the same thing in the grammar of a filter,
      # which is why it read as two things to choose between.
      {:ok, event} =
        Events.create(%{
          "title" => "Vôlei",
          "slug" => "volei-count-#{System.unique_integer([:positive])}",
          "description" => "End: Praia",
          "main_size" => "4",
          "wait_size" => "0",
          "price" => "20",
          "pix_key" => "(91) 98493-3238"
        })

      {:ok, event} = Events.add_to_main(event, "Ana", participant_id: "a")
      {:ok, event} = Events.add_to_main(event, "Bruno", participant_id: "b")
      {:ok, _} = Events.toggle_paid_main(event, 1)

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "1 de 2 já pagaram"
    end

    test "reads plainly once everybody has paid", %{conn: conn} do
      {:ok, event} =
        Events.create(%{
          "title" => "Vôlei",
          "slug" => "volei-all-#{System.unique_integer([:positive])}",
          "description" => "End: Praia",
          "main_size" => "4",
          "wait_size" => "0",
          "price" => "20",
          "pix_key" => "(91) 98493-3238"
        })

      {:ok, event} = Events.add_to_main(event, "Ana", participant_id: "a")
      {:ok, _} = Events.toggle_paid_main(event, 1)

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "todos pagaram"
    end

    test "stays quiet on a free event, where the check reports on nothing", %{conn: conn} do
      event = seed()

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      refute html =~ "já pagaram"
      refute html =~ "todos pagaram"
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

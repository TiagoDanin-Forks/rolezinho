defmodule RolezinhoWeb.RemoveSheetTest do
  @moduledoc """
  RN-22: removal always confirms, and the confirmation names who is going.

  The swipe gesture cannot carry a `data-confirm`, so it opens a sheet instead.
  Reaching that sheet authorizes nothing — the removal itself still goes through
  the policy.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp seed do
    {:ok, event} =
      Events.create(%{
        "title" => "Vôlei",
        "slug" => "volei-remove-#{System.unique_integer([:positive])}",
        "description" => "End: Praia",
        "main_size" => "3",
        "wait_size" => "0"
      })

    {:ok, event} = Events.add_to_main(event, "Ana", participant_id: "someone")
    event
  end

  defp as_admin(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  defp names(slug) do
    Events.find(slug).main_list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))
  end

  describe "the confirmation sheet" do
    test "names the person being removed", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(as_admin(conn), ~p"/r/#{event.slug}")
      html = render_click(view, "ask_remove_main", %{"id" => "1"})

      assert html =~ "Remover Ana da lista?"
      assert has_element?(view, "#remove-sheet")
    end

    test "asking does not remove anyone on its own", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(as_admin(conn), ~p"/r/#{event.slug}")
      render_click(view, "ask_remove_main", %{"id" => "1"})

      assert names(event.slug) == ["Ana"]
    end

    test "cancelling closes it and leaves the list alone", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(as_admin(conn), ~p"/r/#{event.slug}")
      render_click(view, "ask_remove_main", %{"id" => "1"})
      render_click(view, "cancel_remove", %{})

      refute has_element?(view, "#remove-sheet")
      assert names(event.slug) == ["Ana"]
    end

    test "confirming removes and closes the sheet", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(as_admin(conn), ~p"/r/#{event.slug}")
      render_click(view, "ask_remove_main", %{"id" => "1"})
      render_click(view, "remove_main", %{"index" => "1"})

      assert names(event.slug) == []
      refute has_element?(view, "#remove-sheet")
    end

    test "a visitor asking still cannot remove", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")
      render_click(view, "ask_remove_main", %{"id" => "1"})
      render_click(view, "remove_main", %{"index" => "1"})

      # The sheet is presentation; the policy is what refuses.
      assert names(event.slug) == ["Ana"]
    end

    test "a fabricated index opens nothing", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(as_admin(conn), ~p"/r/#{event.slug}")
      render_click(view, "ask_remove_main", %{"id" => "99"})

      refute has_element?(view, "#remove-sheet")
    end
  end

  describe "the swipe accelerator" do
    test "wraps rows the organizer manages", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(as_admin(conn), ~p"/r/#{event.slug}")

      assert has_element?(view, "#swipe-1")
    end

    test "is absent for someone who cannot manage the row", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      refute has_element?(view, "#swipe-1")
    end

    test "never replaces the tappable buttons", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(as_admin(conn), ~p"/r/#{event.slug}")

      # The gesture is an accelerator; the same actions stay reachable.
      assert has_element?(view, ~s{button[aria-label="Remover Ana"]})
    end
  end
end

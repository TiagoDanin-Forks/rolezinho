defmodule RolezinhoWeb.RepeatEventTest do
  @moduledoc """
  RN-52: repeating a rolê copies the setup, not the people.

  The moment somebody wants to repeat is when the last one is over, so on a
  finished event this is the primary action rather than an unlabelled icon in a
  toolbar.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp seed(attrs \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei-repeat-#{System.unique_integer([:positive])}",
      "local" => "Rua Caripunas",
      "price" => "R$ 15",
      "pix_key" => "(91) 98493-3238",
      "main_size" => "4",
      "wait_size" => "2"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  defp as_admin(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  describe "the action" do
    test "leads the page once the rolê is over", %{conn: conn} do
      event = seed()
      {:ok, done} = Events.set_status(event, :done)

      {:ok, _view, html} = live(as_admin(conn), ~p"/r/#{done.slug}")

      assert html =~ "Repetir esse rolê"
    end

    test "is secondary while the rolê is still running", %{conn: conn} do
      event = seed()

      {:ok, _view, html} = live(as_admin(conn), ~p"/r/#{event.slug}")

      assert html =~ "Duplicar pra outra data"
      refute html =~ "Repetir esse rolê"
    end

    test "belongs to the organizer", %{conn: conn} do
      event = seed()

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      refute html =~ "Duplicar"
      refute html =~ "Repetir"
    end
  end

  describe "what a repeat carries over" do
    test "the setup, so nothing has to be typed again", %{conn: conn} do
      event = seed()
      {:ok, event} = Events.add_to_main(event, "Márcia", participant_id: "abc")
      {:ok, done} = Events.set_status(event, :done)

      {:ok, view, _html} = live(as_admin(conn), ~p"/r/#{done.slug}")
      render_click(view, "clone", %{})

      copy = Events.find(done.slug <> "-clonado")
      assert copy.local == "Rua Caripunas"
      assert copy.price_cents == 1500
      assert copy.main_capacity == event.main_capacity
    end

    test "nobody, since it is next week's rolê", %{conn: conn} do
      event = seed()
      {:ok, event} = Events.add_to_main(event, "Márcia", participant_id: "abc")
      {:ok, event} = Events.toggle_paid_main(event, 1)
      {:ok, done} = Events.set_status(event, :done)

      {:ok, view, _html} = live(as_admin(conn), ~p"/r/#{done.slug}")
      render_click(view, "clone", %{})

      copy = Events.find(done.slug <> "-clonado")
      assert Enum.all?(copy.main_list, &(&1.name == ""))
      refute Enum.any?(copy.main_list, & &1.paid)
    end

    test "opens ready to be adjusted", %{conn: conn} do
      event = seed()
      {:ok, done} = Events.set_status(event, :done)

      {:ok, view, _html} = live(as_admin(conn), ~p"/r/#{done.slug}")

      assert {:error, {:live_redirect, %{to: to}}} = render_click(view, "clone", %{})
      assert to =~ "/edit"
    end
  end
end

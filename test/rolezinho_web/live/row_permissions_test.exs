defmodule RolezinhoWeb.RowPermissionsTest do
  @moduledoc """
  RN-12 and RN-21 over the wire.

  Every test here sends the socket message directly, without the button that
  would normally produce it. That is the point: hiding a control is presentation,
  and the server has to refuse on its own.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp seed_event do
    {:ok, event} =
      Events.create(%{
        "title" => "Vôlei",
        "slug" => "volei-rows",
        "description" => "End: Praia",
        "main_size" => "3",
        "wait_size" => "2"
      })

    event
  end

  defp join(conn, slug, name) do
    post(conn, ~p"/r/#{slug}/join", %{"name" => name})
  end

  defp paid_names(slug) do
    Events.find(slug)
    |> Map.fetch!(:main_list)
    |> Enum.filter(& &1.paid)
    |> Enum.map(& &1.name)
  end

  defp names(slug) do
    Events.find(slug)
    |> Map.fetch!(:main_list)
    |> Enum.map(& &1.name)
    |> Enum.reject(&(&1 == ""))
  end

  describe "marking payment (RN-12)" do
    test "a participant marks their own row", %{conn: conn} do
      event = seed_event()
      conn = join(conn, event.slug, "Marcia")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")
      render_click(view, "toggle_paid_main", %{"index" => "1"})

      assert paid_names(event.slug) == ["Marcia"]
    end

    test "a participant cannot mark somebody else's row", %{conn: conn} do
      event = seed_event()
      # Marcia joins from one browser...
      join(conn, event.slug, "Marcia")
      # ...and Roberta from another, which is the one we act from.
      roberta = join(build_conn(), event.slug, "Roberta")

      {:ok, view, _html} = live(roberta, ~p"/r/#{event.slug}")
      render_click(view, "toggle_paid_main", %{"index" => "1"})

      assert paid_names(event.slug) == []
    end

    test "a visitor who joined nothing marks nobody", %{conn: conn} do
      event = seed_event()
      join(build_conn(), event.slug, "Marcia")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")
      render_click(view, "toggle_paid_main", %{"index" => "1"})

      assert paid_names(event.slug) == []
    end

    test "the admin marks anyone (RN-13)", %{conn: conn} do
      event = seed_event()
      join(build_conn(), event.slug, "Marcia")

      admin =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:admin?, true)

      {:ok, view, _html} = live(admin, ~p"/r/#{event.slug}")
      render_click(view, "toggle_paid_main", %{"index" => "1"})

      assert paid_names(event.slug) == ["Marcia"]
    end
  end

  describe "removing (RN-21)" do
    test "a participant removes themselves", %{conn: conn} do
      event = seed_event()
      conn = join(conn, event.slug, "Marcia")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")
      render_click(view, "remove_main", %{"index" => "1"})

      assert names(event.slug) == []
    end

    test "a participant cannot remove somebody else", %{conn: conn} do
      event = seed_event()
      join(conn, event.slug, "Marcia")
      roberta = join(build_conn(), event.slug, "Roberta")

      {:ok, view, _html} = live(roberta, ~p"/r/#{event.slug}")
      render_click(view, "remove_main", %{"index" => "1"})

      assert "Marcia" in names(event.slug)
    end
  end

  describe "a fabricated index" do
    test "past the end of the list changes nothing", %{conn: conn} do
      event = seed_event()
      conn = join(conn, event.slug, "Marcia")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")
      render_click(view, "toggle_paid_main", %{"index" => "99"})

      assert paid_names(event.slug) == []
    end

    test "pointing at an empty slot changes nothing", %{conn: conn} do
      event = seed_event()
      conn = join(conn, event.slug, "Marcia")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")
      render_click(view, "toggle_paid_main", %{"index" => "2"})

      assert paid_names(event.slug) == []
    end

    test "that is not a number changes nothing", %{conn: conn} do
      event = seed_event()
      conn = join(conn, event.slug, "Marcia")

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")
      render_click(view, "toggle_paid_main", %{"index" => "1; drop"})

      assert paid_names(event.slug) == []
    end
  end

  describe "joining" do
    test "issues an identity that survives the redirect", %{conn: conn} do
      event = seed_event()

      slug = event.slug
      conn = join(conn, slug, "Marcia")

      assert %{^slug => id} = Plug.Conn.get_session(conn, "participants")
      assert is_binary(id) and id != ""
    end

    test "puts the name on the list", %{conn: conn} do
      event = seed_event()

      join(conn, event.slug, "Marcia")

      assert names(event.slug) == ["Marcia"]
    end

    test "two browsers get different identities", %{conn: conn} do
      event = seed_event()

      slug = event.slug
      first = join(conn, slug, "Marcia")
      second = join(build_conn(), slug, "Roberta")

      %{^slug => first_id} = Plug.Conn.get_session(first, "participants")
      %{^slug => second_id} = Plug.Conn.get_session(second, "participants")

      refute first_id == second_id
    end
  end
end

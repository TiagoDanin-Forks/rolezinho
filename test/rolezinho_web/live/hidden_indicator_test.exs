defmodule RolezinhoWeb.HiddenIndicatorTest do
  @moduledoc """
  A hidden rolê has a compact visual marker on every list it appears in,
  and a matching badge on its own page. The marker is icon-only so the
  card layout keeps its room for what actually decides a tap (title,
  time, occupancy) — the point is the info is *there*, not that it
  shouts.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Events

  defp create_event(attrs) do
    defaults = %{
      "title" => "Rolê",
      "slug" => "e-#{System.unique_integer([:positive])}",
      "main_size" => "3",
      "wait_size" => "0"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs), admin?: true)
    event
  end

  defp signed_in(conn, login) do
    {:ok, user} =
      Accounts.find_or_create_by_github(%{
        "github_id" => System.unique_integer([:positive]),
        "github_login" => login
      })

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:current_user_id, user.id)

    {conn, user}
  end

  describe "home listing" do
    test "renders the eye-off marker for a hidden rolê the caller owns", %{conn: conn} do
      # An owner sees their hidden rolê on the home
      # (RolezinhoWeb.HomeMyEventsTest covers that shelf); this test
      # asserts the compact marker rides along on the card so the
      # unlisted status is obvious at a glance.
      {conn, user} = signed_in(conn, "owner-hi")

      slug = "mine-hidden-#{System.unique_integer([:positive])}"

      {:ok, event} =
        Events.create(
          %{
            "title" => "Meu oculto",
            "slug" => slug,
            "main_size" => "3",
            "wait_size" => "0"
          },
          created_by_user_id: user.id
        )

      {:ok, _} = Events.set_hidden(event, true)

      {:ok, _view, html} = live(conn, ~p"/")

      # `sr-only` label makes the marker findable in the HTML even though
      # the visible affordance is an icon-only span.
      assert html =~ "Meu oculto"
      assert html =~ "tabler-eye-off"
      assert html =~ "Oculto"
    end

    test "does NOT render the marker for a visible rolê", %{conn: conn} do
      _visible = create_event(%{"title" => "Publico", "slug" => "vis-1"})

      {:ok, _view, html} = live(conn, ~p"/")

      # Public rolê is on the home; the eye-off icon should not be. The
      # icon class is unique to the hidden signal on this page, so its
      # absence is telling.
      assert html =~ "Publico"
      refute html =~ "tabler-eye-off"
    end
  end

  describe "role page" do
    test "renders the Oculto crumb badge when the rolê is hidden", %{conn: conn} do
      event = create_event(%{"title" => "Escondido", "slug" => "hid-page-1"})
      {:ok, _} = Events.set_hidden(event, true)

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      # The crumb badge is a short pill in the breadcrumb line; its label
      # is enough to lock down its presence.
      assert html =~ ">Oculto<"
    end

    test "does NOT render the badge when the rolê is visible", %{conn: conn} do
      event = create_event(%{"title" => "Publico", "slug" => "vis-page-1"})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      refute html =~ ">Oculto<"
    end
  end
end

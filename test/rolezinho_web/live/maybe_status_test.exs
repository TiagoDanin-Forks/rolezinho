defmodule RolezinhoWeb.MaybeStatusTest do
  @moduledoc """
  Coverage for the `:maybe` (\"averiguando resenha\") event status: a
  tentative rol\u00ea whose realization depends on how many people confirm.

  What we exercise here:

    * the schema accepts `:maybe` and lists it in the open / public sets
      (so it appears on the home and its slug is reachable);
    * the events context can set an event to `:maybe` and lists them via
      `list_maybe/0`;
    * home listings render the pill with the tooltip explainer;
    * `/r/:slug` renders the top-of-page notice;
    * the admin edit form exposes the new status as an option.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Event
  alias Rolezinho.Events

  defp create_event(overrides) do
    defaults = %{
      "title" => "Rol\u00ea",
      "slug" => "role-#{System.unique_integer([:positive])}",
      "description" => "",
      "local" => "",
      "date" => "",
      "time" => "",
      "main_size" => "3",
      "wait_size" => "0",
      "password" => ""
    }

    {:ok, event} = Events.create(Map.merge(defaults, overrides), admin?: true)
    event
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  describe "schema" do
    test ":maybe is a valid status enum value" do
      assert :maybe in Event.statuses()
    end

    test ":maybe counts as an open (home-listed) status" do
      # An open status appears on the anonymous home page \u2014 tentative rol\u00eas
      # should show up there so people know they can nudge the outcome.
      assert :maybe in Event.open_statuses()
    end

    test ":maybe counts as a public (slug-reachable) status" do
      assert :maybe in Event.public_statuses()
    end

    test "maybe_status_hint/0 returns a non-empty string" do
      hint = Event.maybe_status_hint()
      assert is_binary(hint)
      assert String.length(hint) > 0
    end
  end

  describe "context" do
    test "set_status/2 accepts :maybe and persists it" do
      event = create_event(%{"title" => "Talvez", "slug" => "talvez-1"})
      assert {:ok, updated} = Events.set_status(event, :maybe)
      assert updated.status == :maybe

      reloaded = Events.find(updated.slug)
      assert reloaded.status == :maybe
    end

    test "list_maybe/0 returns only tentative events" do
      a = create_event(%{"title" => "Certo", "slug" => "certo-a"})
      b = create_event(%{"title" => "Talvez A", "slug" => "talvez-a"})
      c = create_event(%{"title" => "Talvez B", "slug" => "talvez-b"})

      {:ok, _} = Events.set_status(b, :maybe)
      {:ok, _} = Events.set_status(c, :maybe)

      slugs = Events.list_maybe() |> Enum.map(& &1.slug)
      refute a.slug in slugs
      assert b.slug in slugs
      assert c.slug in slugs
    end

    test "list_open/0 (home listing) includes :maybe events" do
      event = create_event(%{"title" => "Talvez home", "slug" => "talvez-home"})
      {:ok, _} = Events.set_status(event, :maybe)

      slugs = Events.list_open() |> Enum.map(& &1.slug)
      assert "talvez-home" in slugs
    end
  end

  describe "home listing pill" do
    test "renders 'Averiguando Resenha' with the info-blue tone and the tooltip",
         %{conn: conn} do
      event = create_event(%{"title" => "Talvez UI", "slug" => "talvez-ui"})
      {:ok, _} = Events.set_status(event, :maybe)

      {:ok, view, html} = live(conn, ~p"/")

      # The card row for this event carries a pill with the label \u2014
      # asserting on the DOM structure so injected framework markers
      # (e.g. `phx-r=\"\"`) don't break the match.
      assert has_element?(view, ~s(a[href="/r/talvez-ui"]))
      assert html =~ "Averiguando Resenha"

      # Native tooltip is what the ask calls for: hovering shows a short
      # explainer. It renders as the `title` attribute on the pill span.
      hint = Event.maybe_status_hint()
      assert html =~ ~s(title="#{hint}")

      # And the pill uses the info-blue tone (solid), our visible
      # differentiator from the other four statuses.
      assert html =~ "bg-info"
    end
  end

  describe "/r/:slug notice" do
    test "renders a top-of-page 'Averiguando Resenha' banner when the status is :maybe",
         %{conn: conn} do
      event = create_event(%{"title" => "Talvez pg", "slug" => "talvez-page"})
      {:ok, _} = Events.set_status(event, :maybe)

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      # The notice shows the title copy and the shared hint one-liner.
      assert html =~ "Averiguando Resenha"
      assert html =~ Event.maybe_status_hint()

      # Same visual family as the payments-only notice \u2014 the same
      # info-toned rounded panel token.
      assert html =~ "border-info/40"
    end

    test "does NOT render the notice when the status is not :maybe", %{conn: conn} do
      event = create_event(%{"title" => "Sem talvez", "slug" => "sem-talvez"})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      # No notice, no hint text.
      refute html =~ Event.maybe_status_hint()
    end
  end

  describe "admin edit form" do
    test "exposes 'Averiguando Resenha' as a status radio option", %{conn: conn} do
      event = create_event(%{"title" => "Editando", "slug" => "editando-1"})
      conn = admin_conn(conn)

      {:ok, view, html} = live(conn, ~p"/admin/r/#{event.slug}/edit")

      # A radio button with the human label.
      assert has_element?(
               view,
               ~s(button[role="radio"][phx-value-status="maybe"])
             )

      assert html =~ "Averiguando Resenha"
    end
  end
end

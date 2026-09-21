defmodule RolezinhoWeb.EventGroupCrumbTest do
  @moduledoc """
  When an event lives inside a group, the back-crumb on `/r/:slug` should
  point to that group's page instead of the generic home listing \u2014 an
  event is not "under Rolezinhos", it is under its group, and that's the
  useful place to go back to.

  Ungrouped events keep the original "\u2190 Rolezinhos" link.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events
  alias Rolezinho.Groups

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

  test "event in a group: back-crumb points at the group", %{conn: conn} do
    {:ok, group} =
      Groups.create(%{"name" => "Meu Grupo", "slug" => "meu-grupo", "visibility" => "public"})

    event = create_event(%{"title" => "Segunda 19h", "slug" => "seg-19-crumb"})
    {:ok, _event} = Events.set_group(event, group.id)

    {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

    # The crumb link points at the group, labelled with the group's name.
    assert has_element?(view, ~s{a[href="/g/meu-grupo"]}, "Meu Grupo")
    # And the generic "Rolezinhos" crumb is gone \u2014 there is only one back link.
    refute has_element?(view, ~s{a[href="/"]}, "Rolezinhos")
  end

  test "ungrouped event: back-crumb keeps pointing at the home page", %{conn: conn} do
    event = create_event(%{"title" => "Solto", "slug" => "solto-crumb"})

    {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

    assert has_element?(view, ~s{a[href="/"]}, "Rolezinhos")
  end
end

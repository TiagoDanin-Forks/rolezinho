defmodule RolezinhoWeb.GroupHomeListingTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events
  alias Rolezinho.Groups

  defp create_group(overrides \\ %{}) do
    defaults = %{"name" => "Grupo", "slug" => "g", "visibility" => "public"}
    {:ok, group} = Groups.create(Map.merge(defaults, overrides))
    group
  end

  defp create_event(group_id, overrides) do
    defaults = %{
      "title" => "Rolê",
      "slug" => "role-#{System.unique_integer([:positive])}",
      "description" => "",
      "local" => "",
      "date" => "",
      "time" => "",
      "main_size" => "3",
      "wait_size" => "0",
      "password" => ""
    }

    {:ok, event} =
      Events.create(Map.merge(defaults, overrides), admin?: true, group_id: group_id)

    event
  end

  test "public groups appear on the home listing above ungrouped events", %{conn: conn} do
    _group = create_group(%{"slug" => "publico", "name" => "Grupo Público"})
    _ungrouped = create_event(nil, %{"title" => "Rolê solto", "slug" => "solto-1"})

    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "Grupo Público"
    assert html =~ "Rolê solto"

    # The group list has a stable id we can hook into.
    assert has_element?(view, "#group-list")
    assert has_element?(view, "a[href='/g/publico']")
  end

  test "hidden groups do not appear on the home listing", %{conn: conn} do
    _hidden = create_group(%{"slug" => "oculto", "visibility" => "hidden", "name" => "Oculto"})

    {:ok, _view, html} = live(conn, ~p"/")

    refute html =~ "Oculto"
  end

  test "events belonging to a group are absent from the home listing", %{conn: conn} do
    group = create_group()
    _grouped = create_event(group.id, %{"title" => "Dentro do grupo", "slug" => "in-group-1"})
    _ungrouped = create_event(nil, %{"title" => "Fora do grupo", "slug" => "out-group-1"})

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Fora do grupo"
    refute html =~ "Dentro do grupo"
  end
end

defmodule RolezinhoWeb.GroupEventCreationTest do
  @moduledoc """
  Creating an event *into* a group is deliberately gated on the caller's
  access to the group. A visitor who cannot edit the group cannot drop a
  new event into it, either — otherwise the passwordless-groups-are-
  admin-only rule would be trivially bypassed by anyone with the URL.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events
  alias Rolezinho.Groups

  defp create_group(overrides) do
    defaults = %{"name" => "Grupo", "slug" => "g1", "visibility" => "public"}
    {:ok, group} = Groups.create(Map.merge(defaults, overrides))
    group
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  defp unlocked_group_conn(conn, slug) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:unlocked_groups, MapSet.new([slug]))
  end

  defp base_event_params(overrides) do
    Map.merge(
      %{
        "title" => "Novo",
        "slug" => "novo-#{System.unique_integer([:positive])}",
        "description" => "",
        "local" => "",
        "date" => "",
        "time" => "",
        "price" => "",
        "pix_key" => "",
        "main_size" => "3",
        "wait_size" => "0",
        "password" => ""
      },
      overrides
    )
  end

  describe "GroupNewLive route + form" do
    test "the form pre-fills the group hidden field when `?group=` is present", %{conn: conn} do
      group = create_group(%{"slug" => "prefilled"})
      {:ok, view, html} = live(conn, ~p"/criar?group=#{group.slug}")

      # The banner names the group the user is creating into.
      assert html =~ "Grupo"
      # And the hidden field carries the slug on submit.
      assert has_element?(view, "input[name='event[group]'][value='prefilled']")
    end
  end

  describe "POST /criar with a group" do
    test "admin can attach any event to any group and lands on the group page", %{conn: conn} do
      group = create_group(%{"slug" => "adm-target"})

      conn =
        post(admin_conn(conn), ~p"/criar", %{
          "event" => base_event_params(%{"title" => "Admin One", "group" => "adm-target"})
        })

      assert redirected_to(conn) == "/g/adm-target"
      [event] = Groups.list_events(group, visibility: :with_hidden)
      assert event.title == "Admin One"
      assert event.group_id == group.id
      # And it's active (grouped events don't get the anonymous-hidden default).
      assert event.status == :active
    end

    test "non-admin with a group unlock can attach", %{conn: conn} do
      group = create_group(%{"slug" => "unlocked-target", "password" => "s"})

      conn =
        post(unlocked_group_conn(conn, "unlocked-target"), ~p"/criar", %{
          "event" =>
            base_event_params(%{
              "title" => "Unlocked",
              "slug" => "unl-1",
              "group" => "unlocked-target"
            })
        })

      assert redirected_to(conn) == "/g/unlocked-target"
      assert Events.find("unl-1").group_id == group.id
    end

    test "non-admin without any unlock is NOT dropped into a passwordless group", %{conn: conn} do
      group = create_group(%{"slug" => "public-untouchable"})

      conn =
        post(conn, ~p"/criar", %{
          "event" =>
            base_event_params(%{
              "title" => "Rejected",
              "slug" => "rej-1",
              "group" => "public-untouchable"
            })
        })

      # Event is created, but ungrouped, and a flash explains why.
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "acesso"
      event = Events.find("rej-1")
      assert event
      assert is_nil(event.group_id)

      # And of course the group didn't get it.
      assert Groups.list_events(group, visibility: :any) == []
    end

    test "unknown group name flashes and creates ungrouped", %{conn: conn} do
      conn =
        post(conn, ~p"/criar", %{
          "event" =>
            base_event_params(%{
              "title" => "NoGroup",
              "slug" => "nogrp-1",
              "group" => "does-not-exist"
            })
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "não encontrado"
      assert Events.find("nogrp-1").group_id == nil
    end
  end
end

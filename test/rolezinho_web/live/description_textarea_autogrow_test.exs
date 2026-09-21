defmodule RolezinhoWeb.DescriptionTextareaAutogrowTest do
  @moduledoc """
  The description textarea should start small (2 rows) and grow as the
  user types, up to a cap of 5 rows. Modern CSS handles the grow via
  `field-sizing: content` on a `textarea[data-autogrow]` selector in
  `app.css`; the tests here just guarantee the markup carries the
  bindings the CSS relies on \u2014 the two forms where a description is
  written (\"new event\" and \"edit event\").
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Events

  # Signing in is what unlocks the create form (ADR-0002); an anonymous
  # visitor is redirected. The edit form is admin-only.
  defp signed_in_conn(conn) do
    {:ok, user} =
      Accounts.find_or_create_by_github(%{
        "github_id" => System.unique_integer([:positive]),
        "github_login" => "gh-autogrow"
      })

    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
  end

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  test "new event form: description textarea has rows=2 and data-autogrow", %{conn: conn} do
    conn = signed_in_conn(conn)
    {:ok, view, _html} = live(conn, ~p"/criar")

    # rows=\"2\" gives the initial size and the fallback for browsers without
    # `field-sizing: content`.
    assert has_element?(view, ~s(textarea[name="event[description]"][rows="2"][data-autogrow]))
  end

  test "edit event form: description textarea has rows=2 and data-autogrow", %{conn: conn} do
    # An admin session gets past the edit gate without going through OAuth.
    conn = admin_conn(conn)

    {:ok, event} =
      Events.create(
        %{
          "title" => "Rol\u00ea",
          "slug" => "auto-#{System.unique_integer([:positive])}",
          "description" => "",
          "local" => "",
          "date" => "",
          "time" => "",
          "main_size" => "3",
          "wait_size" => "0",
          "password" => ""
        },
        admin?: true
      )

    {:ok, view, _html} = live(conn, ~p"/admin/r/#{event.slug}/edit")

    # The details card uses `as: :details`, so the textarea's name is
    # `details[description]` rather than `event[description]`.
    assert has_element?(view, ~s(textarea[name="details[description]"][rows="2"][data-autogrow]))
  end
end

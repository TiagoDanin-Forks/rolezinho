defmodule RolezinhoWeb.NamePrefillFromGithubTest do
  @moduledoc """
  ADR-0002: on first visit after signing in, we seed the device's `/me`
  profile name from the GitHub identity — so the join sheet auto-fills
  with the user's name without them ever having to visit `/me`. The
  seeding runs client-side in the `.Settings` and `.JoinDefaults` hooks;
  what we verify here is that the *data* the hooks need reaches the DOM
  (a `data-current-user-name` attribute on the right elements).
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Events

  defp signed_in_conn(conn, attrs \\ %{}) do
    defaults = %{
      "github_id" => System.unique_integer([:positive]),
      "github_login" => "octocat",
      "name" => "Octo Cat"
    }

    {:ok, user} = Accounts.find_or_create_by_github(Map.merge(defaults, attrs))

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Plug.Conn.put_session(:current_user_id, user.id)

    %{conn: conn, user: user}
  end

  describe "/me settings screen" do
    test "signed in: the settings root carries the user's GitHub display name",
         %{conn: conn} do
      %{conn: conn} = signed_in_conn(conn)
      {:ok, _view, html} = live(conn, ~p"/me")

      assert html =~ ~s(data-current-user-name="Octo Cat")
    end

    test "falls back to the GitHub login when the user has no display name",
         %{conn: conn} do
      %{conn: conn} = signed_in_conn(conn, %{"name" => nil, "github_login" => "octo"})
      {:ok, _view, html} = live(conn, ~p"/me")

      assert html =~ ~s(data-current-user-name="octo")
    end

    test "anonymous: the attribute is present but empty (hook stays a no-op)",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/me")

      assert html =~ ~s(data-current-user-name="")
    end

    test "the .Settings hook is bound to the settings root", %{conn: conn} do
      # Colocated hook JS is extracted at compile time and lives in the app
      # bundle, not inline in the response. What we can check from HTML is
      # that the hook is bound to the element that carries the data attr.
      %{conn: conn} = signed_in_conn(conn)
      {:ok, view, _html} = live(conn, ~p"/me")

      assert has_element?(
               view,
               ~s(#settings[phx-hook][data-current-user-name="Octo Cat"])
             )
    end
  end

  describe "join sheet on the event page" do
    test "signed in: the join form carries the user's GitHub display name and hooks the seeder",
         %{conn: conn} do
      %{conn: conn} = signed_in_conn(conn)

      {:ok, event} =
        Events.create(
          %{
            "title" => "R",
            "slug" => "np-#{System.unique_integer([:positive])}",
            "main_size" => "3",
            "wait_size" => "0"
          },
          admin?: true
        )

      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ ~s(data-current-user-name="Octo Cat")

      # Colocated hook JS is stripped from the response (extracted at
      # compile time into the app bundle). We check the wiring instead —
      # the JoinDefaults hook is bound to the form that carries the attr.
      assert has_element?(
               view,
               ~s(form#join-form[phx-hook][data-current-user-name="Octo Cat"])
             )
    end

    test "anonymous: the attribute is empty (hook stays a no-op)", %{conn: conn} do
      {:ok, event} =
        Events.create(
          %{
            "title" => "R",
            "slug" => "np2-#{System.unique_integer([:positive])}",
            "main_size" => "3",
            "wait_size" => "0"
          },
          admin?: true
        )

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      # Attribute is present with an empty string \\-\\- the hook's
      # `if (fromGithub && !profile.name)` guard short-circuits.
      assert html =~ ~s(data-current-user-name="")
    end
  end
end

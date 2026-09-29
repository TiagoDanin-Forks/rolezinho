defmodule RolezinhoWeb.SettingsEmailPanelTest do
  @moduledoc """
  Coverage for the email panel on `/me`.

  A signed-in user should be able to add, change, or clear their
  email address without leaving the settings screen. An anonymous
  visitor should not see the panel at all — the "sign in to manage
  this" path is the correct affordance for them.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Repo

  defp register(overrides \\ %{}) do
    n = System.unique_integer([:positive])

    defaults = %{
      "username" => "meform#{n}",
      "password" => "supersecret",
      "email" => "meform#{n}@example.com",
      "name" => "Me Form"
    }

    {:ok, user} = Accounts.register_user(Map.merge(defaults, overrides))
    user
  end

  defp signed_in(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
  end

  test "signed-in user sees the email panel pre-filled with their address", %{conn: conn} do
    user = register()
    conn = signed_in(conn, user)

    {:ok, view, _html} = live(conn, ~p"/me")

    assert has_element?(
             view,
             ~s(form[phx-submit="save_email"] input[name="email"][value="#{user.email}"])
           )
  end

  test "signed-in user with no email sees the panel with an empty field", %{conn: conn} do
    user = register(%{"email" => nil})
    conn = signed_in(conn, user)

    {:ok, view, _html} = live(conn, ~p"/me")

    # `value=""` is how the empty state renders (we always pass an
    # empty-string fallback in the template).
    assert has_element?(view, ~s(form[phx-submit="save_email"] input[name="email"][value=""]))
  end

  test "anonymous visitor does not see the email panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/me")

    refute has_element?(view, ~s(form[phx-submit="save_email"]))
  end

  test "submitting a new email persists it and shows a success flash", %{conn: conn} do
    user = register()
    conn = signed_in(conn, user)

    {:ok, view, _html} = live(conn, ~p"/me")

    view
    |> form(~s(form[phx-submit="save_email"]), %{"email" => "changed@example.com"})
    |> render_submit()

    reloaded = Repo.reload!(user)
    assert reloaded.email == "changed@example.com"

    html = render(view)
    assert html =~ "Email atualizado"
  end

  test "submitting an empty value clears the email", %{conn: conn} do
    user = register()
    conn = signed_in(conn, user)

    {:ok, view, _html} = live(conn, ~p"/me")

    view
    |> form(~s(form[phx-submit="save_email"]), %{"email" => ""})
    |> render_submit()

    reloaded = Repo.reload!(user)
    assert reloaded.email == nil

    html = render(view)
    assert html =~ "Email removido"
  end

  test "submitting an over-length email shows an inline error", %{conn: conn} do
    user = register()
    conn = signed_in(conn, user)

    {:ok, view, _html} = live(conn, ~p"/me")

    huge = String.duplicate("a", 250) <> "@example.com"

    view
    |> form(~s(form[phx-submit="save_email"]), %{"email" => huge})
    |> render_submit()

    html = render(view)
    assert html =~ "Email muito longo"

    # And the DB is untouched.
    reloaded = Repo.reload!(user)
    assert reloaded.email == user.email
  end

  # Regression: `save_email` from an anonymous socket must be a
  # silent no-op. The panel is not rendered for them, but the
  # handler still exists and would be hit by a fabricated event.
  test "save_email from an anonymous socket is a silent no-op", %{conn: conn} do
    user = register()

    # Sign in, load the page, then simulate the anonymous case by
    # calling the handler on a fresh live() with no session.
    {:ok, view, _html} = live(conn, ~p"/me")

    render_hook(view, "save_email", %{"email" => "hacker@example.com"})

    # User's email stays put.
    reloaded = Repo.reload!(user)
    assert reloaded.email == user.email
  end
end

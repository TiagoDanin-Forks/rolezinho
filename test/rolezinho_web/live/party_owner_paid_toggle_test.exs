defmodule RolezinhoWeb.PartyOwnerPaidToggleTest do
  @moduledoc """
  Regression for the party-owner paid checkbox on `/r/:slug`.

  Someone who joins with guests owns every row they created (all rows share
  the same `participant_id` — see `Rolezinho.Event.add_party/4`). The
  server-side `Rolezinho.Event.Policy.can_toggle_paid?/3` allows toggling
  any owned row, but the LiveView template used to gate the check on a
  single `mine_index` — the first row you own — so a party leader could
  only mark their own paid, never their guest's. This test locks in the
  fix by asserting the `toggle_paid_main` button is wired on both rows.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp create_event(overrides \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "party-toggle-#{System.unique_integer([:positive])}",
      "description" => "",
      "main_size" => "3",
      "wait_size" => "0",
      "price_cents" => "2000",
      "pix_key" => "12345678900",
      "pix_key_type" => "cpf"
    }

    {:ok, event} = Events.create(Map.merge(defaults, overrides), admin?: true)
    event
  end

  defp owner_conn(conn, participant_id, slug) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:participants, %{slug => participant_id})
  end

  describe "party owner can toggle paid on every row they own" do
    test "both the primary row and the guest row expose toggle_paid_main",
         %{conn: conn} do
      event = create_event()

      # One browser (one participant_id) joins as Fulano with a guest
      # Beltrano — the two attendees now share the same identity.
      {:ok, _event, %{main: 2}} =
        Events.add_party(event, "Fulano", 2,
          participant_id: "tok-party",
          guest_names: ["Beltrano"]
        )

      conn = owner_conn(conn, "tok-party", event.slug)
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      # Primary row (Fulano) — always worked.
      assert has_element?(
               view,
               ~s(button[phx-click="toggle_paid_main"][phx-value-index="1"])
             )

      # Guest row (Beltrano) — regression: this button used to be absent
      # because `mine?` was `mine_index == index`, and `mine_index` only
      # tracked the first-matched row.
      assert has_element?(
               view,
               ~s(button[phx-click="toggle_paid_main"][phx-value-index="2"])
             )
    end

    test "toggling the guest row actually flips paid on that row", %{conn: conn} do
      event = create_event()

      {:ok, _event, %{main: 2}} =
        Events.add_party(event, "Fulano", 2,
          participant_id: "tok-party",
          guest_names: ["Beltrano"]
        )

      conn = owner_conn(conn, "tok-party", event.slug)
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      view
      |> element(~s(button[phx-click="toggle_paid_main"][phx-value-index="2"]))
      |> render_click()

      reloaded = Events.find(event.slug)
      [primary, guest | _] = reloaded.main_list
      assert primary.name == "Fulano"
      refute primary.paid
      assert guest.name == "Beltrano"
      assert guest.paid
    end

    test "a stranger with no identity still gets no toggle button", %{conn: conn} do
      # The gate loosened for owners must not accidentally open for
      # visitors. Anonymous browser, no participant token in session.
      event = create_event()

      {:ok, _event, %{main: 2}} =
        Events.add_party(event, "Fulano", 2,
          participant_id: "tok-party",
          guest_names: ["Beltrano"]
        )

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      refute has_element?(
               view,
               ~s(button[phx-click="toggle_paid_main"][phx-value-index="1"])
             )

      refute has_element?(
               view,
               ~s(button[phx-click="toggle_paid_main"][phx-value-index="2"])
             )
    end

    test "party owner can remove their guest row too", %{conn: conn} do
      # Symmetric fix: the remove button uses the same `mine?` gate, so
      # if paid was wrong for guests, remove was wrong for guests too.
      event = create_event()

      {:ok, _event, %{main: 2}} =
        Events.add_party(event, "Fulano", 2,
          participant_id: "tok-party",
          guest_names: ["Beltrano"]
        )

      conn = owner_conn(conn, "tok-party", event.slug)
      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      assert has_element?(
               view,
               ~s(button[phx-click="remove_main"][phx-value-index="2"])
             )
    end
  end
end

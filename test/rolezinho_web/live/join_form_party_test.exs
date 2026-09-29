defmodule RolezinhoWeb.JoinFormPartyTest do
  @moduledoc """
  The join sheet's party controls + name autocomplete:

    * a `<datalist>` full of recent canonical names for signed-in users,
      empty for anonymous callers;
    * `party_room - 1` pre-rendered guest inputs, hidden until the
      client-side hook activates them based on the qty stepper;
    * the join POST accepts `guest_names[]` and each guest lands with
      their own typed name.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Events

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

  defp create_event(overrides \\ %{}) do
    defaults = %{
      "title" => "T",
      "slug" => "e-#{System.unique_integer([:positive])}",
      "main_size" => "5",
      "wait_size" => "0"
    }

    {:ok, event} = Events.create(Map.merge(defaults, overrides), admin?: true)
    event
  end

  describe "autocomplete datalists" do
    test "renders one <option> per recent canonical name in both datalists",
         %{conn: conn} do
      # There are two: `join-name-suggestions` for the user's own name,
      # and `join-guest-suggestions` (starts as a copy, filtered live by
      # the .PartyGuests hook) for the guest fields.
      {conn, user} = signed_in(conn, "auto-1")

      e1 = create_event()

      {:ok, _, _} =
        Events.add_party(e1, "pedro Costa", 1,
          participant_id: "t1",
          user_id: user.id
        )

      e2 = create_event()

      {:ok, _, _} =
        Events.add_party(e2, "Ana", 1, participant_id: "t2", user_id: user.id)

      target = create_event()
      {:ok, view, _html} = live(conn, ~p"/r/#{target.slug}")

      for id <- ["join-name-suggestions", "join-guest-suggestions"] do
        assert has_element?(view, "datalist##{id}")
        assert has_element?(view, ~s(datalist##{id} option[value="Pedro Costa"]))
        assert has_element?(view, ~s(datalist##{id} option[value="Ana"]))
      end
    end

    test "renders both datalists empty for an anonymous caller", %{conn: conn} do
      event = create_event()

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      for id <- ["join-name-suggestions", "join-guest-suggestions"] do
        assert has_element?(view, "datalist##{id}")
        refute has_element?(view, "datalist##{id} option")
      end
    end

    test "guest inputs reference the guest datalist, name input references its own",
         %{conn: conn} do
      event = create_event(%{"main_size" => "5", "wait_size" => "0"})

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      # User's own name -> its own suggestion pool.
      assert has_element?(
               view,
               ~s(input[name="name"][list="join-name-suggestions"])
             )

      # Guests -> the filtered pool (the .PartyGuests hook prunes the
      # user's own name from this one on every keystroke).
      assert has_element?(
               view,
               ~s(input[name="guest_names[]"][list="join-guest-suggestions"])
             )
    end
  end

  describe "guest inputs" do
    test "renders party_room - 1 guest inputs, hidden and disabled by default",
         %{conn: conn} do
      # party_room caps at max_party_size (9) when the wait list is on;
      # this event has wait_size 0 so party_room = free main slots = 5.
      event = create_event(%{"main_size" => "5", "wait_size" => "0"})

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      # 4 guest slots for the 5-cap. Each carries the marker attr the
      # hook uses.
      for index <- 1..4 do
        assert has_element?(
                 view,
                 ~s([data-guest-slot][data-guest-index="#{index}"])
               )
      end

      # A hostile submit without the hook active still lands with the
      # inputs disabled, so no phantom guest names sneak in.
      assert has_element?(view, ~s(input[data-guest-input][disabled]))
    end

    test "does NOT render guest inputs when party_room is 1", %{conn: conn} do
      # A 1-slot main list + no wait list = the stepper doesn't render
      # and neither do the guest inputs.
      event = create_event(%{"main_size" => "1", "wait_size" => "0"})

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}")

      refute has_element?(view, "#party-guests")
    end
  end

  describe "join POST with guest_names[]" do
    test "each guest lands with their own typed name", %{conn: conn} do
      event = create_event(%{"main_size" => "5", "wait_size" => "0"})

      post(conn, ~p"/r/#{event.slug}/join", %{
        "name" => "Márcia",
        "qty" => "3",
        "guest_names" => ["Bruno", "Pedro"]
      })

      reloaded = Events.find(event.slug)
      names = reloaded.main_list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))
      assert names == ["Márcia", "Bruno", "Pedro"]
    end

    test "a blank guest name falls back to \"Convidado de <you>\" for that slot",
         %{conn: conn} do
      event = create_event(%{"main_size" => "5", "wait_size" => "0"})

      post(conn, ~p"/r/#{event.slug}/join", %{
        "name" => "Márcia",
        "qty" => "3",
        "guest_names" => ["", "Pedro"]
      })

      reloaded = Events.find(event.slug)
      names = reloaded.main_list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))
      assert names == ["Márcia", "Convidado de Márcia", "Pedro"]
    end

    test "no guest_names in POST body \u2014 old behavior (all Convidado de X)",
         %{conn: conn} do
      event = create_event(%{"main_size" => "5", "wait_size" => "0"})

      post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Márcia", "qty" => "3"})

      reloaded = Events.find(event.slug)
      names = reloaded.main_list |> Enum.map(& &1.name) |> Enum.reject(&(&1 == ""))
      assert names == ["Márcia", "Convidado de Márcia", "Convidado de Márcia"]
    end
  end
end

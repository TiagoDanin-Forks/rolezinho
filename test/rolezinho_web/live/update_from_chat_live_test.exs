defmodule RolezinhoWeb.UpdateFromChatLiveTest do
  @moduledoc """
  End-to-end coverage for `/atualizar` — the URL-driven bulk update
  surface an LLM points a human at.

  Two flows:

    * **picker** — no `event=<slug>`, we render the caller's updatable
      events; picking one keeps the LLM params intact.
    * **diff** — `event=<slug>` resolves, the two-column view renders,
      the human confirms, the DB reflects the changes.

  Anonymous visitors get bounced to `/entrar` with `return_to` set,
  so an LLM link they clicked before signing in still reaches its
  destination after auth.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Accounts
  alias Rolezinho.Events

  defp register do
    n = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        "username" => "chat#{n}",
        "password" => "supersecret"
      })

    user
  end

  defp signed_in(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
  end

  defp create_event(user, overrides \\ %{}) do
    n = System.unique_integer([:positive])

    defaults = %{
      "title" => "Vôlei",
      "slug" => "chatv-#{n}",
      "main_size" => "4",
      "wait_size" => "0"
    }

    {:ok, event} =
      Events.create(Map.merge(defaults, overrides), created_by_user_id: user.id)

    event
  end

  describe "anonymous access" do
    test "bounces to /entrar with return_to preserved", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: to}}} =
               live(conn, ~p"/atualizar?names[0]=Alice")

      assert String.starts_with?(to, "/entrar?")
      assert to =~ "return_to=%2Fatualizar"
      # The names[0]=Alice bit survives the round trip (percent-encoded
      # inside return_to).
      assert to =~ "names"
    end
  end

  describe "picker" do
    test "shows the user's updatable events when no `event` param",
         %{conn: conn} do
      user = register()
      event = create_event(user)
      conn = signed_in(conn, user)

      {:ok, view, html} = live(conn, ~p"/atualizar")

      assert html =~ "Atualizar rolezinho"
      assert has_element?(view, "a", event.title)
    end

    test "empty state when the user has no updatable events", %{conn: conn} do
      user = register()
      conn = signed_in(conn, user)

      {:ok, _view, html} = live(conn, ~p"/atualizar")
      assert html =~ "Você não tem rolês"
    end

    test "picker link preserves LLM query params", %{conn: conn} do
      user = register()
      event = create_event(user)
      conn = signed_in(conn, user)

      {:ok, view, _html} = live(conn, ~p"/atualizar?names[0]=Alice&checks[0]=1")

      # The picker row's href includes both the chosen event and the
      # original LLM params.
      assert has_element?(view, ~s(a[href*="event=#{event.slug}"][href*="names"]))
    end

    test "an `event` slug the caller cannot update falls back to the picker",
         %{conn: conn} do
      owner = register()
      other = register()
      event = create_event(owner)
      conn = signed_in(conn, other)

      {:ok, _view, html} = live(conn, ~p"/atualizar?event=#{event.slug}")

      # Falls back to the picker (empty for `other`).
      assert html =~ "Você não tem rolês"
    end
  end

  describe "diff view" do
    setup %{conn: conn} do
      user = register()
      event = create_event(user)
      {:ok, event, _} = Events.add_party(event, "Bruno", 1, participant_id: "tok-bruno")

      %{conn: signed_in(conn, user), user: user, event: event}
    end

    test "renders both columns with the LLM proposal on the right",
         %{conn: conn, event: event} do
      params = %{"event" => event.slug, "names" => %{"0" => "Alice"}, "checks" => %{"0" => "1"}}
      {:ok, _view, html} = live(conn, ~p"/atualizar?#{params}")

      # Left (antes) shows Bruno at slot 1.
      assert html =~ "Bruno"
      # Right (depois) has an input pre-filled with Alice.
      assert html =~ ~s(value="Alice")
      # Paid checkbox for row 1 is checked (`checks[0]=1` → slot 1).
      assert html =~ ~s(name="main[1][paid]") and html =~ ~s(checked)
    end

    test "confirm submits the form and applies the update",
         %{conn: conn, event: event} do
      params = %{"event" => event.slug, "names" => %{"0" => "Alice"}, "checks" => %{"0" => "1"}}
      {:ok, view, _html} = live(conn, ~p"/atualizar?#{params}")

      # Simulate what a click on "Confirmar" would send: the whole
      # form with LLM defaults intact. `render_submit/2` on the form
      # serialises the current input values.
      assert {:error, {:live_redirect, %{to: to}}} =
               view
               |> form("#confirm-form")
               |> render_submit()

      assert to == "/r/#{event.slug}"

      reloaded = Events.find(event.slug)
      [first | _] = reloaded.main_list
      assert first.name == "Alice"
      assert first.paid == true
      # Different name → identity dropped (Bruno's participant_id gone).
      assert first.participant_id == nil
    end

    test "new field chips render and can be discarded",
         %{conn: conn, event: event} do
      params = %{
        "event" => event.slug,
        "names" => %{"0" => "Alice"},
        "fields" => %{"0" => %{"tamanho" => "M"}}
      }

      {:ok, view, html} = live(conn, ~p"/atualizar?#{params}")

      # New-field chip is present.
      assert html =~ "Campos novos"
      assert has_element?(view, ~s(button[phx-click="discard_field"][phx-value-key="tamanho"]))

      # Discard it.
      view
      |> element(~s(button[phx-click="discard_field"][phx-value-key="tamanho"]))
      |> render_click()

      html = render(view)
      # Chip is gone — and so are the per-row inputs that were
      # rendered for the pending field.
      refute has_element?(view, ~s(button[phx-click="discard_field"][phx-value-key="tamanho"]))
      refute html =~ ~s(name="main[1][values][tamanho]")
    end

    test "confirming with a new-field chip creates the field on the event",
         %{conn: conn, event: event} do
      params = %{
        "event" => event.slug,
        "names" => %{"0" => "Alice"},
        "fields" => %{"0" => %{"tamanho" => "M"}}
      }

      {:ok, view, _html} = live(conn, ~p"/atualizar?#{params}")

      view
      |> form("#confirm-form")
      |> render_submit()

      reloaded = Events.find(event.slug)
      # Field exists.
      assert Enum.any?(reloaded.form_fields, &(&1.id == "tamanho"))
      # Alice's row carries the value.
      [first | _] = reloaded.main_list
      assert first.name == "Alice"
      assert Map.get(first.values, "tamanho") == "M"
    end

    test "field_labels[<key>] carries through to the created field's label",
         %{conn: conn, event: event} do
      params = %{
        "event" => event.slug,
        "names" => %{"0" => "Alice"},
        "fields" => %{"0" => %{"nome-na-camisa" => "Alice A."}},
        "field_labels" => %{"nome-na-camisa" => "Nome na camisa"}
      }

      {:ok, view, html} = live(conn, ~p"/atualizar?#{params}")

      # Chip shows the human-cased label, not the humanized slug
      # ("Nome Na Camisa").
      assert html =~ "Nome na camisa"
      refute html =~ "Nome Na Camisa"

      view
      |> form("#confirm-form")
      |> render_submit()

      reloaded = Events.find(event.slug)
      field = Enum.find(reloaded.form_fields, &(&1.id == "nome-na-camisa"))
      # Field created with the LLM-supplied label, casing preserved.
      assert field.label == "Nome na camisa"
    end
  end

  describe "capacity" do
    setup %{conn: conn} do
      user = register()
      event = create_event(user, %{"main_size" => "4"})
      %{conn: signed_in(conn, user), event: event}
    end

    test "the diff header renders the capacity input pre-filled",
         %{conn: conn, event: event} do
      params = %{"event" => event.slug, "capacity" => "6"}
      {:ok, view, _html} = live(conn, ~p"/atualizar?#{params}")

      # Input is present and pre-filled with 6, and the "antes"
      # badge shows the current capacity (4) so the change is
      # visible before submit.
      assert has_element?(view, ~s(input[name="capacity"][value="6"]))
      assert render(view) =~ "antes: 4"
    end

    test "submitting the form applies the new capacity",
         %{conn: conn, event: event} do
      params = %{"event" => event.slug, "capacity" => "6"}
      {:ok, view, _html} = live(conn, ~p"/atualizar?#{params}")

      view
      |> form("#confirm-form")
      |> render_submit()

      reloaded = Events.find(event.slug)
      assert reloaded.main_capacity == 6
    end

    test "URL name at a slot past current capacity grows implicitly",
         %{conn: conn, event: event} do
      # Slot 5 (0-based 4) is past the event's capacity of 4.
      params = %{"event" => event.slug, "names" => %{"4" => "Ester"}}
      {:ok, view, _html} = live(conn, ~p"/atualizar?#{params}")

      # Header capacity input auto-bumps to fit.
      assert has_element?(view, ~s(input[name="capacity"][value="5"]))

      view
      |> form("#confirm-form")
      |> render_submit()

      reloaded = Events.find(event.slug)
      assert reloaded.main_capacity == 5
      assert Enum.at(reloaded.main_list, 4).name == "Ester"
    end
  end

  describe "wait custom fields" do
    setup %{conn: conn} do
      user = register()

      event =
        create_event(user, %{"main_size" => "2", "wait_size" => "3"})

      {:ok, event} = Events.add_form_field(event, %{"label" => "Tamanho"})
      {:ok, event} = Events.add_to_wait(event, "Ana", participant_id: "tok-ana")

      %{conn: signed_in(conn, user), event: event}
    end

    test "wait_fields values render on the wait depois column",
         %{conn: conn, event: event} do
      params = %{
        "event" => event.slug,
        "wait_names" => %{"0" => "Ana"},
        "wait_fields" => %{"0" => %{"tamanho" => "P"}}
      }

      {:ok, view, _html} = live(conn, ~p"/atualizar?#{params}")

      # The wait scope's field input exists and is pre-filled.
      assert has_element?(
               view,
               ~s(input[name="wait[1][values][tamanho]"][value="P"])
             )
    end

    test "confirm persists the wait-row's custom-field value",
         %{conn: conn, event: event} do
      params = %{
        "event" => event.slug,
        "wait_names" => %{"0" => "Ana"},
        "wait_fields" => %{"0" => %{"tamanho" => "P"}}
      }

      {:ok, view, _html} = live(conn, ~p"/atualizar?#{params}")

      view
      |> form("#confirm-form")
      |> render_submit()

      reloaded = Events.find(event.slug)
      [wait_first | _] = reloaded.wait_list
      assert wait_first.name == "Ana"
      assert Map.get(wait_first.values, "tamanho") == "P"
    end
  end
end

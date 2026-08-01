defmodule RolezinhoWeb.InviteLiveTest do
  @moduledoc """
  The screen a shared link opens (spec 03).

  It answers "are my people going?" before asking for anything, and it offers a
  way to look without joining — someone who only wants to know where it is
  should not have to put their name on a list to find out.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp seed(attrs \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei-invite-#{System.unique_integer([:positive])}",
      "local" => "Rua Caripunas",
      "date" => "2026-08-15",
      "time" => "19:00",
      "price" => "R$ 15",
      "pix_key" => "(91) 98493-3238",
      "main_size" => "6",
      "wait_size" => "2"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  defp with_people(event, names) do
    Enum.reduce(names, event, fn name, acc ->
      {:ok, acc} = Events.add_to_main(acc, name, participant_id: "seed-#{name}")
      acc
    end)
  end

  describe "social proof (RN-42)" do
    test "leads with who is already in", %{conn: conn} do
      event = seed() |> with_people(["Márcia", "Roberta"])

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/convite")

      assert html =~ "2/6 confirmados"
    end

    test "invites the first person in when nobody has joined", %{conn: conn} do
      event = seed()

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/convite")

      assert html =~ "Você pode ser o primeiro"
    end
  end

  describe "the details" do
    test "carries where, when and how much", %{conn: conn} do
      event = seed()

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/convite")

      assert html =~ "Rua Caripunas"
      assert html =~ "15/08"
      assert html =~ "R$ 15"
    end

    test "omits the amount for a free event", %{conn: conn} do
      event = seed(%{"price" => "", "pix_key" => ""})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/convite")

      refute html =~ "Quanto"
    end
  end

  describe "the two ways out" do
    test "offers joining and looking without joining", %{conn: conn} do
      event = seed()

      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}/convite")

      assert html =~ "Entrar na lista"
      assert has_element?(view, ~s{a[href="/r/#{event.slug}"]}, "Só ver a lista")
    end

    test "someone already in is only offered the list", %{conn: conn} do
      event = seed()
      conn = post(conn, ~p"/r/#{event.slug}/join", %{"name" => "Bruno"})

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}/convite")

      refute has_element?(view, "#join-form")
      assert has_element?(view, ~s{a[href="/r/#{event.slug}"]}, "Ver a lista")
    end

    test "a full list offers the queue instead (RN-03)", %{conn: conn} do
      event = seed(%{"main_size" => "1"}) |> with_people(["Ana"])

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/convite")

      assert html =~ "Entrar na espera"
    end
  end

  describe "the password gate (RN-41)" do
    test "shows the invitation but not the names or the address", %{conn: conn} do
      event = seed(%{"password" => "segredo"}) |> with_people(["Márcia"])

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/convite")

      assert html =~ "Vôlei"
      refute html =~ "Márcia"
      refute html =~ "Rua Caripunas"
      assert html =~ "pede senha"
    end

    test "does not offer joining before the password", %{conn: conn} do
      event = seed(%{"password" => "segredo"})

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}/convite")

      refute has_element?(view, "#join-form")
    end

    test "opens up once unlocked", %{conn: conn} do
      event = seed(%{"password" => "segredo"}) |> with_people(["Márcia"])

      unlocked =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:unlocked_events, MapSet.new([event.slug]))

      {:ok, view, html} = live(unlocked, ~p"/r/#{event.slug}/convite")

      assert html =~ "Rua Caripunas"
      assert has_element?(view, "#join-form")
    end
  end

  describe "companions (RN-04)" do
    test "offers the counter when there is room for more than one", %{conn: conn} do
      event = seed()

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}/convite")

      assert has_element?(view, ~s{input[name="qty"]})
    end

    test "hides it when only one slot is left and there is no queue", %{conn: conn} do
      event = seed(%{"main_size" => "2", "wait_size" => "0"}) |> with_people(["Ana"])

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}/convite")

      refute has_element?(view, ~s{input[name="qty"]})
    end
  end
end

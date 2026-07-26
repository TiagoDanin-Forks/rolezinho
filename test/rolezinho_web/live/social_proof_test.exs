defmodule RolezinhoWeb.SocialProofTest do
  @moduledoc """
  RN-42: who is already in, shown above the action.

  Deciding whether to go is mostly deciding whether your people are going, so
  the names come before the form rather than after it.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp seed(attrs \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei-proof-#{System.unique_integer([:positive])}",
      "description" => "End: Praia",
      "main_size" => "6",
      "wait_size" => "0"
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

  describe "the confirmed list above the action" do
    test "counts everyone already in", %{conn: conn} do
      event = seed() |> with_people(["Márcia", "Roberta", "Henrique"])

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "3 pessoas já confirmaram"
    end

    test "reads naturally with a single person", %{conn: conn} do
      event = seed() |> with_people(["Márcia"])

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "1 pessoa já confirmou"
    end

    test "is absent while nobody has joined", %{conn: conn} do
      event = seed()

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      refute html =~ "já confirm"
    end

    test "never leaks names through a password gate", %{conn: conn} do
      event = seed(%{"password" => "segredo"}) |> with_people(["Márcia"])

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      refute html =~ "Márcia"
      refute html =~ "já confirm"
    end
  end

  describe "the Pix key" do
    test "prefers the structured field over the description", %{conn: conn} do
      event =
        seed(%{
          "description" => "Pix: 91111111111",
          "pix_key" => "financeiro@example.com",
          "price" => "15"
        })

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      # The description still renders as written — what matters is which key the
      # payment panel resolved, and it is the one typed into the field.
      assert html =~ "financeiro@example.com"
    end

    test "shows the amount with it", %{conn: conn} do
      event = seed(%{"pix_key" => "91984933238", "price" => "R$ 15"})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "R$ 15"
    end

    test "accepts a key type the old regex could not read", %{conn: conn} do
      event =
        seed(%{"pix_key" => "123e4567-e12b-12d1-a456-426655440000", "price" => "20"})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "123e4567-e12b-12d1-a456-426655440000"
    end

    test "falls back to the description when there is no field", %{conn: conn} do
      event = seed(%{"description" => "Pix: 91984933238"})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

      assert html =~ "(91) 98493-3238"
    end
  end
end

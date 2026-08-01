defmodule RolezinhoWeb.EventEditPaymentTest do
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp admin_conn(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin?, true)
  end

  defp seed(overrides \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei",
      "main_size" => "3",
      "wait_size" => "0",
      "price" => "",
      "pix_key" => ""
    }

    {:ok, event} = Events.create(Map.merge(defaults, overrides))
    event
  end

  describe "the payment form on /admin/r/:slug/edit" do
    test "is pre-filled with the event's current price and Pix key", %{conn: conn} do
      event = seed(%{"price" => "15,50", "pix_key" => "91984933238"})

      {:ok, view, _html} =
        live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      # The <input> value= attributes carry the round-tripped values.
      assert view |> element("#payment-form input[name='payment[price]']") |> render() =~
               ~s(value="15,50")

      assert view |> element("#payment-form input[name='payment[pix_key]']") |> render() =~
               ~s(value="91984933238")
    end

    test "leaves the price input empty when the event has none", %{conn: conn} do
      event = seed()

      {:ok, view, _html} =
        live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      html = view |> element("#payment-form input[name='payment[price]']") |> render()
      # No value attribute or explicit empty value.
      refute html =~ ~s(value="15")
      assert html =~ ~s(value="") or not (html =~ ~r/value="[^"]/)
    end

    test "saving both fields updates the DB row and flashes success", %{conn: conn} do
      event = seed()

      {:ok, view, _html} =
        live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      html =
        view
        |> form("#payment-form", %{"payment" => %{"price" => "15", "pix_key" => "91984933238"}})
        |> render_submit()

      assert html =~ "Valor e Pix atualizados"

      reloaded = Events.find(event.slug)
      assert reloaded.price_cents == 1500
      assert reloaded.pix_key == "91984933238"
    end

    test "clearing both fields wipes them on the row", %{conn: conn} do
      event = seed(%{"price" => "42", "pix_key" => "x@y"})

      {:ok, view, _html} =
        live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      view
      |> form("#payment-form", %{"payment" => %{"price" => "", "pix_key" => ""}})
      |> render_submit()

      reloaded = Events.find(event.slug)
      assert reloaded.price_cents == nil
      assert reloaded.pix_key == nil
    end

    test "after saving, the form re-renders with the round-tripped values", %{conn: conn} do
      event = seed()

      {:ok, view, _html} =
        live(admin_conn(conn), ~p"/admin/r/#{event.slug}/edit")

      view
      |> form("#payment-form", %{
        "payment" => %{"price" => "15,50", "pix_key" => "  91984933238  "}
      })
      |> render_submit()

      # The input reflects the current price stored (with the same formatting the
      # create form would accept).
      assert view |> element("#payment-form input[name='payment[price]']") |> render() =~
               ~s(value="15,50")

      # The pix key was trimmed by the context before saving.
      reloaded = Events.find(event.slug)
      assert reloaded.pix_key == "91984933238"
    end

    test "non-admins can't reach the edit page in the first place", %{conn: conn} do
      event = seed()

      assert {:error, {:redirect, %{to: "/admin/login"}}} =
               live(conn, ~p"/admin/r/#{event.slug}/edit")
    end
  end
end

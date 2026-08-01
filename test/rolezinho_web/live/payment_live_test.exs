defmodule RolezinhoWeb.PaymentLiveTest do
  @moduledoc """
  The screen someone lands on right after getting a slot.

  It exists because the payment is the part that quietly does not happen: on the
  list the key is one detail among many, here it is the only thing.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp paid_event(attrs \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "volei-pay-#{System.unique_integer([:positive])}",
      "description" => "End: Praia",
      "main_size" => "4",
      "wait_size" => "2",
      "price" => "R$ 15",
      "pix_key" => "91984933238"
    }

    {:ok, event} = Events.create(Map.merge(defaults, attrs))
    event
  end

  defp join(conn, slug, params \\ %{}) do
    post(conn, ~p"/r/#{slug}/join", Map.merge(%{"name" => "Bruno"}, params))
  end

  describe "arriving here" do
    test "joining a paid event routes to payment", %{conn: conn} do
      event = paid_event()

      conn = join(conn, event.slug)

      assert redirected_to(conn) == "/r/#{event.slug}/pagamento"
    end

    test "joining a free event goes straight back to the list", %{conn: conn} do
      event = paid_event(%{"price" => "", "pix_key" => ""})

      conn = join(conn, event.slug)

      assert redirected_to(conn) == "/r/#{event.slug}"
    end

    test "an event with a price but no key has nothing to show", %{conn: conn} do
      event = paid_event(%{"pix_key" => ""})

      conn = join(conn, event.slug)

      assert redirected_to(conn) == "/r/#{event.slug}"
    end
  end

  describe "the screen" do
    test "leads with the amount", %{conn: conn} do
      event = paid_event()
      conn = join(conn, event.slug)

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/pagamento")

      assert html =~ "R$ 15"
      assert html =~ "Sua parte"
    end

    test "offers the key and its QR code", %{conn: conn} do
      # Written with punctuation so it reads as a phone: eleven bare digits are
      # ambiguous with a CPF, and the classifier defaults to CPF there.
      event = paid_event(%{"pix_key" => "(91) 98493-3238"})
      conn = join(conn, event.slug)

      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}/pagamento")

      assert html =~ "(91) 98493-3238"
      assert has_element?(view, "#copy-pix-key")
      assert html =~ "<svg"
    end

    test "shows a CPF key formatted as a CPF", %{conn: conn} do
      event = paid_event(%{"pix_key" => "12345678900"})
      conn = join(conn, event.slug)

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/pagamento")

      assert html =~ "123.456.789-00"
    end

    test "says which list the person landed in", %{conn: conn} do
      event = paid_event(%{"main_size" => "1"})
      {:ok, _} = Events.add_to_main(event, "Ana", participant_id: "someone")

      conn = join(conn, event.slug)
      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/pagamento")

      assert html =~ "na espera"
    end
  end

  describe "declaring payment (RN-11)" do
    test "the button records what happened elsewhere", %{conn: conn} do
      event = paid_event()
      conn = join(conn, event.slug)

      {:ok, view, html} = live(conn, ~p"/r/#{event.slug}/pagamento")
      assert html =~ "Já fiz o Pix"

      render_click(view, "mark_paid", %{})

      assert Events.find(event.slug).main_list |> Enum.any?(& &1.paid)
    end

    test "someone who already declared is not asked again", %{conn: conn} do
      event = paid_event()
      conn = join(conn, event.slug)

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}/pagamento")
      render_click(view, "mark_paid", %{})

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/pagamento")
      refute html =~ "Já fiz o Pix"
      assert html =~ "Ver a lista"
    end

    test "a visitor holding no row declares nothing", %{conn: conn} do
      event = paid_event()
      join(build_conn(), event.slug)

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}/pagamento")
      render_click(view, "mark_paid", %{})

      refute Events.find(event.slug).main_list |> Enum.any?(& &1.paid)
    end

    test "the button is absent for someone who never joined", %{conn: conn} do
      event = paid_event()

      {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/pagamento")

      refute html =~ "Já fiz o Pix"
    end
  end

  describe "paying later" do
    test "there is always a way out that is not paying", %{conn: conn} do
      event = paid_event()
      conn = join(conn, event.slug)

      {:ok, view, _html} = live(conn, ~p"/r/#{event.slug}/pagamento")

      assert has_element?(view, ~s{a[href="/r/#{event.slug}"]}, "Pago depois")
    end
  end
end

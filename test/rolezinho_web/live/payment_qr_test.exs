defmodule RolezinhoWeb.PaymentQrTest do
  @moduledoc """
  The QR block on `/r/:slug/pagamento`: big enough to scan without
  pinching to zoom, on a theme-invariant white canvas so it stays
  readable in dark mode.

  These are shallow assertions on the class names + size hints. The
  actual QR bytes are covered elsewhere (`Rolezinho.PixTest`); here we
  are locking down the visual contract that made the QR unusable in
  the issue that prompted this change.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp paid_event(overrides \\ %{}) do
    defaults = %{
      "title" => "Vôlei",
      "slug" => "pay-#{System.unique_integer([:positive])}",
      "main_size" => "3",
      "wait_size" => "0",
      "price" => "R$ 15",
      "pix_key" => "91984933238",
      "pix_key_type" => "phone"
    }

    {:ok, event} = Events.create(Map.merge(defaults, overrides), admin?: true)
    event
  end

  test "renders the QR on the dedicated white canvas token", %{conn: conn} do
    event = paid_event()

    {:ok, view, html} = live(conn, ~p"/r/#{event.slug}/pagamento")

    # `bg-qr-canvas` is a theme-invariant white token (see DESIGN.md and
    # the @theme block in app.css). Its presence is the fix for the "black
    # QR on a dark background" issue.
    assert has_element?(view, "#pix-qr-canvas.bg-qr-canvas")
    # And the SVG inside is the big 256px size, not the compact 148px one.
    assert html =~ "size-[256px]"
  end
end

defmodule RolezinhoWeb.PixDisplayTest do
  @moduledoc """
  End-to-end: an event whose `pix_key_type` is `:phone` renders its key
  as a phone on both the event page and the payment page, even when the
  raw key was typed as a bare 11-digit number.

  Regression: the display path used to call `Pix.display/1` (which
  guesses from the string) instead of `Pix.display_as/2` (which honors
  the explicit type), so a phone key showed up formatted as a CPF.
  """
  use RolezinhoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Rolezinho.Events

  defp phone_event do
    {:ok, event} =
      Events.create(
        %{
          "title" => "Vôlei",
          "slug" => "phone-#{System.unique_integer([:positive])}",
          "main_size" => "3",
          "wait_size" => "0",
          "price" => "R$ 15",
          "pix_key" => "91984933238",
          "pix_key_type" => "phone"
        },
        admin?: true
      )

    event
  end

  test "the event page shows the key formatted as a phone", %{conn: conn} do
    event = phone_event()

    {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}")

    # Phone format: "(91) 98493-3238". CPF format would have been
    # "919.849.332-38" — asserting both makes the regression obvious.
    assert html =~ "(91) 98493-3238"
    refute html =~ "919.849.332-38"
  end

  test "the payment page shows the key formatted as a phone", %{conn: conn} do
    event = phone_event()

    {:ok, _view, html} = live(conn, ~p"/r/#{event.slug}/pagamento")

    assert html =~ "(91) 98493-3238"
    refute html =~ "919.849.332-38"
  end
end

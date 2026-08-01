defmodule Rolezinho.EventsUpdatePaymentTest do
  use Rolezinho.DataCase, async: true

  alias Rolezinho.Event
  alias Rolezinho.Events

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

  describe "update_payment/2" do
    test "sets both price and pix from empty" do
      event = seed()
      assert event.price_cents in [nil, 0]
      assert event.pix_key in [nil, ""]

      {:ok, updated} =
        Events.update_payment(event, %{"price" => "15", "pix_key" => "91984933238"})

      assert updated.price_cents == 1500
      assert updated.pix_key == "91984933238"
    end

    test "parses decimal prices the same way the create form does" do
      event = seed()

      {:ok, whole} = Events.update_payment(event, %{"price" => "15", "pix_key" => ""})
      assert whole.price_cents == 1500

      {:ok, comma} = Events.update_payment(whole, %{"price" => "15,50", "pix_key" => ""})
      assert comma.price_cents == 1550

      {:ok, prefixed} =
        Events.update_payment(comma, %{"price" => "R$ 20,00", "pix_key" => ""})

      assert prefixed.price_cents == 2000
    end

    test "clears both fields when submitted blank" do
      event =
        seed(%{"price" => "20", "pix_key" => "someone@example.com"})

      # Sanity: the create form did set them.
      assert event.price_cents == 2000
      assert event.pix_key == "someone@example.com"

      {:ok, cleared} =
        Events.update_payment(event, %{"price" => "", "pix_key" => "   "})

      assert cleared.price_cents == nil
      assert cleared.pix_key == nil
    end

    test "invalid price becomes nil rather than raising" do
      event = seed(%{"price" => "15"})
      {:ok, updated} = Events.update_payment(event, %{"price" => "n/a", "pix_key" => "x"})
      assert updated.price_cents == nil
      assert updated.pix_key == "x"
    end

    test "accepts every DICT key type the Pix module recognizes" do
      event = seed()

      Enum.each(
        [
          # phone (various shapes)
          "91984933238",
          "(91) 98493-3238",
          "+55 91 98493-3238",
          # CPF
          "123.456.789-00",
          # email
          "someone@example.com",
          # random UUID
          "abcdefgh-1234-5678-9abc-def012345678"
        ],
        fn key ->
          {:ok, updated} =
            Events.update_payment(event, %{"price" => "10", "pix_key" => key})

          assert updated.pix_key == key,
                 "expected #{inspect(key)} to round-trip, got #{inspect(updated.pix_key)}"
        end
      )
    end

    test "does not touch header, meta, password, lists or slug" do
      event =
        seed(%{
          "local" => "Rua Caripunas",
          "description" => "Valor: 15\nPix: 91984933238",
          "password" => "sesamo"
        })

      original_slug = event.slug
      original_header = event.header
      original_password = event.password
      original_main = Enum.map(event.main_list, & &1.name)

      {:ok, updated} =
        Events.update_payment(event, %{"price" => "42", "pix_key" => "novo@pix.com"})

      assert updated.slug == original_slug
      assert updated.header == original_header
      assert updated.password == original_password
      assert Enum.map(updated.main_list, & &1.name) == original_main

      assert updated.price_cents == 4200
      assert updated.pix_key == "novo@pix.com"
    end

    test "broadcasts :updated on the event topic" do
      event = seed()
      Events.subscribe(event.slug)

      {:ok, _updated} =
        Events.update_payment(event, %{"price" => "15", "pix_key" => "x@y"})

      assert_receive {:updated, %Event{price_cents: 1500, pix_key: "x@y"}}
    end
  end
end

defmodule Rolezinho.EventsPixPairTest do
  @moduledoc """
  `Events.create/2`, `update_payment/2` and `update_full_details/2` all
  enforce the (pix_key, pix_key_type) pair:

    * both nil / blank — fine, no Pix.
    * key set, type nil — error "escolha o tipo da chave".
    * key set, type set — key must canonicalize under the type,
      otherwise a `:pix_key` shape error.

  The point of the pair is to end the "11-digit phone read as CPF" bug
  by making the organizer state the type outright.
  """
  use Rolezinho.DataCase, async: true

  alias Rolezinho.Events

  defp base_params(overrides \\ %{}) do
    Map.merge(
      %{
        "title" => "Vôlei",
        "slug" => "e-#{System.unique_integer([:positive])}",
        "main_size" => "3",
        "wait_size" => "0"
      },
      overrides
    )
  end

  describe "Events.create/2" do
    test "no pix_key + no pix_key_type is fine" do
      assert {:ok, event} = Events.create(base_params(), admin?: true)
      assert event.pix_key == nil
      assert event.pix_key_type == nil
    end

    test "pix_key without a type is rejected" do
      assert {:error, errors} =
               Events.create(base_params(%{"pix_key" => "91984933238"}), admin?: true)

      assert Map.has_key?(errors, :pix_key_type)
    end

    test "pix_key + matching type saves both" do
      params = base_params(%{"pix_key" => "91984933238", "pix_key_type" => "phone"})
      assert {:ok, event} = Events.create(params, admin?: true)
      assert event.pix_key == "91984933238"
      assert event.pix_key_type == :phone
    end

    test "11-digit key with :cpf type is saved as CPF, with :phone as phone" do
      # The whole point of the pair.
      params_a =
        base_params(%{"slug" => "a", "pix_key" => "12345678900", "pix_key_type" => "cpf"})

      assert {:ok, a} = Events.create(params_a, admin?: true)
      assert a.pix_key_type == :cpf

      params_b =
        base_params(%{"slug" => "b", "pix_key" => "12345678900", "pix_key_type" => "phone"})

      assert {:ok, b} = Events.create(params_b, admin?: true)
      assert b.pix_key_type == :phone
    end

    test "key that cannot be canonicalized under the given type errors on :pix_key" do
      params =
        base_params(%{
          "pix_key" => "not-an-email",
          "pix_key_type" => "email"
        })

      assert {:error, errors} = Events.create(params, admin?: true)
      assert Map.has_key?(errors, :pix_key)
    end

    test "blank pix_key + a type silently clears the type" do
      params = base_params(%{"pix_key" => "  ", "pix_key_type" => "phone"})
      assert {:ok, event} = Events.create(params, admin?: true)
      assert event.pix_key == nil
      assert event.pix_key_type == nil
    end
  end

  describe "Events.update_payment/2" do
    setup do
      {:ok, event} = Events.create(base_params(), admin?: true)
      %{event: event}
    end

    test "same pair rules apply on update", %{event: event} do
      assert {:error, errors} =
               Events.update_payment(event, %{"price" => "10", "pix_key" => "91984933238"})

      assert Map.has_key?(errors, :pix_key_type)
    end

    test "successful update persists both", %{event: event} do
      assert {:ok, updated} =
               Events.update_payment(event, %{
                 "price" => "10",
                 "pix_key" => "91984933238",
                 "pix_key_type" => "phone"
               })

      assert updated.pix_key == "91984933238"
      assert updated.pix_key_type == :phone
    end
  end
end

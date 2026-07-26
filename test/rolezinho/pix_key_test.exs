defmodule Rolezinho.PixKeyTest do
  @moduledoc """
  Key classification against the five DICT types.

  The canonical form is not cosmetic: the BR Code carries the key verbatim, so a
  key in the wrong shape produces a QR that scans and then fails to route.
  """
  use ExUnit.Case, async: true

  alias Rolezinho.Pix

  describe "phone keys" do
    test "a local number gains the country code" do
      assert Pix.classify("(91) 98493-3238") == {:ok, :phone, "+5591984933238"}
    end

    test "a number already carrying +55 is kept" do
      assert Pix.classify("+5591984933238") == {:ok, :phone, "+5591984933238"}
    end

    test "punctuation is dropped, not preserved" do
      assert Pix.classify("+55 (91) 98493-3238") == {:ok, :phone, "+5591984933238"}
    end

    test "a landline works too" do
      assert Pix.classify("(91) 3242-1234") == {:ok, :phone, "+559132421234"}
    end
  end

  describe "CPF and CNPJ" do
    test "a punctuated CPF becomes digits only" do
      assert Pix.classify("123.456.789-00") == {:ok, :cpf, "12345678900"}
    end

    test "a bare 11-digit string is read as a CPF" do
      # Ambiguous with a mobile number; CPF is the safer reading, since guessing
      # phone would send money toward somebody else's real number.
      assert Pix.classify("12345678900") == {:ok, :cpf, "12345678900"}
    end

    test "a punctuated CNPJ becomes digits only" do
      assert Pix.classify("00.038.166/0001-05") == {:ok, :cnpj, "00038166000105"}
    end
  end

  describe "email and random keys" do
    test "an email is lowercased" do
      assert Pix.classify("Financeiro@Example.COM") == {:ok, :email, "financeiro@example.com"}
    end

    test "a random key keeps its hyphens" do
      key = "123e4567-e12b-12d1-a456-426655440000"

      assert Pix.classify(key) == {:ok, :random, key}
    end

    test "a random key is accepted in upper case" do
      assert {:ok, :random, "123e4567-e12b-12d1-a456-426655440000"} =
               Pix.classify("123E4567-E12B-12D1-A456-426655440000")
    end
  end

  describe "rejections" do
    test "nothing at all" do
      assert Pix.classify(nil) == :error
      assert Pix.classify("") == :error
      assert Pix.classify("   ") == :error
    end

    test "free text" do
      assert Pix.classify("me paga depois") == :error
    end

    test "a number of no recognizable length" do
      assert Pix.classify("12345") == :error
    end

    test "an email missing its domain" do
      assert Pix.classify("financeiro@") == :error
    end
  end

  describe "normalize/1 and display/1" do
    test "normalize returns the form the BR Code carries" do
      assert Pix.normalize("(91) 98493-3238") == "+5591984933238"
      assert Pix.normalize("nope") == nil
    end

    test "display keeps a key recognizable to whoever typed it" do
      assert Pix.display("+5591984933238") == "(91) 98493-3238"
      assert Pix.display("12345678900") == "123.456.789-00"
      assert Pix.display("00038166000105") == "00.038.166/0001-05"
      assert Pix.display("financeiro@example.com") == "financeiro@example.com"
    end
  end

  describe "the payload accepts every type" do
    test "each canonical key round-trips into a valid BR Code" do
      for input <- [
            "(91) 98493-3238",
            "123.456.789-00",
            "00.038.166/0001-05",
            "financeiro@example.com",
            "123e4567-e12b-12d1-a456-426655440000"
          ] do
        key = Pix.normalize(input)
        payload = Pix.brcode(key, name: "MARCIA", city: "BELEM")

        assert payload =~ key
        assert String.match?(payload, ~r/6304[0-9A-F]{4}$/)
      end
    end
  end
end

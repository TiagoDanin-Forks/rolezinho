defmodule Rolezinho.PixCanonicalizeTest do
  @moduledoc """
  `Pix.canonicalize/2` — the guess-free path. The organizer picks a type,
  the function returns the canonical form for that type or `:error`. No
  ambiguity between an 11-digit phone and an 11-digit CPF: the caller
  said which one it is.
  """
  use ExUnit.Case, async: true

  alias Rolezinho.Pix

  describe ":phone" do
    test "an 11-digit bare number is a phone when the caller says so" do
      assert Pix.canonicalize("91984933238", :phone) == {:ok, "+5591984933238"}
    end

    test "a punctuated number is a phone" do
      assert Pix.canonicalize("(91) 98493-3238", :phone) == {:ok, "+5591984933238"}
    end

    test "a number already carrying +55 is kept" do
      assert Pix.canonicalize("+5591984933238", :phone) == {:ok, "+5591984933238"}
    end

    test "a landline (10 local digits) works" do
      assert Pix.canonicalize("(91) 3242-1234", :phone) == {:ok, "+559132421234"}
    end

    test "a 9-digit number is not a phone" do
      assert Pix.canonicalize("123456789", :phone) == :error
    end
  end

  describe ":cpf" do
    test "a bare 11-digit is a CPF when the caller says so (same string, different type)" do
      assert Pix.canonicalize("12345678900", :cpf) == {:ok, "12345678900"}
    end

    test "a punctuated CPF loses the punctuation" do
      assert Pix.canonicalize("123.456.789-00", :cpf) == {:ok, "12345678900"}
    end

    test "a 10-digit string is not a CPF" do
      assert Pix.canonicalize("1234567890", :cpf) == :error
    end
  end

  describe ":cnpj" do
    test "a 14-digit string is a CNPJ" do
      assert Pix.canonicalize("00038166000105", :cnpj) == {:ok, "00038166000105"}
    end

    test "a punctuated CNPJ loses the punctuation" do
      assert Pix.canonicalize("00.038.166/0001-05", :cnpj) == {:ok, "00038166000105"}
    end
  end

  describe ":email" do
    test "a valid email is downcased" do
      assert Pix.canonicalize("Financeiro@Example.COM", :email) ==
               {:ok, "financeiro@example.com"}
    end

    test "a bare string is not an email" do
      assert Pix.canonicalize("not-an-email", :email) == :error
    end
  end

  describe ":random" do
    test "a UUID is accepted" do
      key = "123e4567-e12b-12d1-a456-426655440000"
      assert Pix.canonicalize(key, :random) == {:ok, key}
    end

    test "a phone-shaped string is not a random key" do
      assert Pix.canonicalize("91984933238", :random) == :error
    end
  end

  describe "safety" do
    test "an unknown type returns :error rather than crashing" do
      assert Pix.canonicalize("something", :something_else) == :error
    end

    test "blank / nil / non-binary return :error" do
      assert Pix.canonicalize("", :phone) == :error
      assert Pix.canonicalize(nil, :phone) == :error
      assert Pix.canonicalize(123, :phone) == :error
    end
  end

  describe "display_as/2" do
    test "an 11-digit key with :phone renders as a phone, not a CPF" do
      # The bug this method fixes: `display/1` guesses and would format the
      # same string as "123.456.789-00" because a bare 11-digit falls
      # through to CPF in the guesser.
      assert Pix.display_as("91984933238", :phone) == "(91) 98493-3238"
    end

    test "the same 11-digit key with :cpf renders as a CPF" do
      assert Pix.display_as("91984933238", :cpf) == "919.849.332-38"
    end

    test "a punctuated phone is normalized to the compact format" do
      assert Pix.display_as("(91) 98493-3238", :phone) == "(91) 98493-3238"
    end

    test "a punctuated CPF drops punctuation on the canonical then re-formats" do
      assert Pix.display_as("123.456.789-00", :cpf) == "123.456.789-00"
    end

    test "an email is displayed lowercased" do
      assert Pix.display_as("HI@X.COM", :email) == "hi@x.com"
    end

    test "a random key is displayed as-is (lowercased)" do
      key = "123E4567-E12B-12D1-A456-426655440000"
      assert Pix.display_as(key, :random) == String.downcase(key)
    end

    test "nil / unknown type returns nil rather than crashing" do
      assert Pix.display_as("whatever", :bogus) == nil
      assert Pix.display_as(nil, :phone) == nil
    end
  end

  describe "type metadata" do
    test "types/0 lists the five DICT types in the form-friendly order" do
      assert Pix.types() == [:phone, :cpf, :cnpj, :email, :random]
    end

    test "type_label/1 returns a Portuguese label for each type" do
      for type <- Pix.types() do
        label = Pix.type_label(type)
        assert is_binary(label)
        assert label != ""
      end
    end
  end
end

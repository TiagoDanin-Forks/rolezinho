defmodule Rolezinho.Event.TokenTest do
  use ExUnit.Case, async: true

  alias Rolezinho.Event.Token

  describe "generate_organizer/0" do
    test "produces a distinct value on every call" do
      tokens = Enum.map(1..100, fn _ -> Token.generate_organizer() end)

      assert length(Enum.uniq(tokens)) == 100
    end

    test "produces a URL-safe value that survives a link or a QR code" do
      token = Token.generate_organizer()

      assert token =~ ~r/^[A-Za-z0-9_-]+$/
      assert URI.encode_www_form(token) == token
    end

    test "carries enough entropy that guessing is not a strategy" do
      # 32 raw bytes, base64url-encoded without padding.
      assert String.length(Token.generate_organizer()) == 43
    end
  end

  describe "generate_participant/0" do
    test "produces a distinct value on every call" do
      ids = Enum.map(1..100, fn _ -> Token.generate_participant() end)

      assert length(Enum.uniq(ids)) == 100
    end

    test "never collides with an organizer token" do
      participant = Token.generate_participant()

      refute participant == Token.generate_organizer()
    end
  end
end

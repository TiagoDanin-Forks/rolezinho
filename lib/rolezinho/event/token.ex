defmodule Rolezinho.Event.Token do
  @moduledoc """
  Opaque secrets for the two identities this app has.

  There are no accounts here, so both identities are bearer secrets held by the
  browser: whoever presents the value is treated as that party. Two consequences
  follow, and both are deliberate.

  An organizer token is the only thing standing between a visitor and
  administering someone else's event, so it is generated from a CSPRNG and long
  enough that guessing is not a strategy. A participant id only claims a row in
  one list — worth far less — but is generated the same way because there is no
  reason to make it cheaper.

  Neither is derived from anything about the person: not the name, not the
  device, not the time. A token that encodes something can be reasoned about
  backwards; these can only be stored and compared.
  """

  # 32 bytes of entropy, URL-safe so the value survives a link, a QR code and a
  # copy-paste out of a chat message without escaping.
  @bytes 32

  @doc """
  Generates the secret that authorizes administering one event.

  ## Examples

      iex> token = Rolezinho.Event.Token.generate_organizer()
      iex> String.length(token) >= 32
      true
  """
  @spec generate_organizer() :: String.t()
  def generate_organizer, do: random()

  @doc """
  Generates the id that claims a row in a list.

  ## Examples

      iex> id = Rolezinho.Event.Token.generate_participant()
      iex> id != Rolezinho.Event.Token.generate_participant()
      true
  """
  @spec generate_participant() :: String.t()
  def generate_participant, do: random()

  defp random do
    @bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end

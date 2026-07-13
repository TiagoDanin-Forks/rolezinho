defmodule Rolezinho.Pix do
  @moduledoc """
  Detects a PIX key (Brazilian instant payments) in the event description and
  builds an EMV/BR Code payload plus an SVG QR code for it.

  Only phone-number PIX keys are currently detected (the most common case for
  informal events like `Pix: 91985609019`). Numbers without a country code are
  normalized to `+55<digits>`.
  """

  import Bitwise

  @default_name "ROLEZINHO"
  @default_city "BRASIL"

  @doc """
  Scans free-form text (typically the event description) for a PIX phone key.

  Returns `%{key: "+55...", raw: "91985609019", display: "(91) 98560-9019"}`
  when a phone-shaped key is found, or `nil`.
  """
  @spec detect(String.t()) :: %{key: String.t(), raw: String.t(), display: String.t()} | nil
  def detect(text) when is_binary(text) do
    with [_, raw] <- Regex.run(~r/(?:p\s*i\s*x|chave)[^\d+]*([+\d][\d\s\-().]{9,20})/iu, text),
         digits when digits != "" <- Regex.replace(~r/\D/, raw, ""),
         key when is_binary(key) <- normalize_phone(digits) do
      %{key: key, raw: digits, display: format_phone(key)}
    else
      _ -> nil
    end
  end

  def detect(_), do: nil

  defp normalize_phone(digits) do
    cond do
      String.starts_with?(digits, "55") and byte_size(digits) in [12, 13] ->
        "+" <> digits

      byte_size(digits) in [10, 11] ->
        "+55" <> digits

      true ->
        nil
    end
  end

  defp format_phone("+55" <> rest) do
    case rest do
      <<a::binary-size(2), b::binary-size(5), c::binary-size(4)>> -> "(#{a}) #{b}-#{c}"
      <<a::binary-size(2), b::binary-size(4), c::binary-size(4)>> -> "(#{a}) #{b}-#{c}"
      _ -> "+55" <> rest
    end
  end

  defp format_phone(other), do: other

  @doc """
  Builds a static PIX BR Code payload for the given key. Follows the
  EMV® QRCPS-Merchant-Presented specification used by the Brazilian PIX.
  """
  @spec brcode(String.t(), keyword()) :: String.t()
  def brcode(pix_key, opts \\ []) when is_binary(pix_key) do
    name = opts |> Keyword.get(:name, @default_name) |> normalize_ascii() |> String.slice(0, 25)
    city = opts |> Keyword.get(:city, @default_city) |> normalize_ascii() |> String.slice(0, 15)

    merchant_account =
      tlv("00", "BR.GOV.BCB.PIX") <> tlv("01", pix_key)

    additional_data = tlv("05", "***")

    body =
      tlv("00", "01") <>
        tlv("26", merchant_account) <>
        tlv("52", "0000") <>
        tlv("53", "986") <>
        tlv("58", "BR") <>
        tlv("59", name) <>
        tlv("60", city) <>
        tlv("62", additional_data)

    prefix = body <> "6304"
    prefix <> crc16(prefix)
  end

  @doc """
  Renders the QR code for the given PIX key as an SVG string.
  """
  @spec qr_svg(String.t(), keyword()) :: String.t()
  def qr_svg(pix_key, opts \\ []) do
    payload = brcode(pix_key, opts)

    payload
    |> EQRCode.encode()
    |> EQRCode.svg(width: Keyword.get(opts, :width, 220), background_color: :transparent)
  end

  # ---------- helpers ----------

  defp tlv(id, value) when is_binary(id) and is_binary(value) do
    len =
      value
      |> byte_size()
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    id <> len <> value
  end

  # Strip diacritics and any non-ASCII printable so the BR Code stays valid.
  defp normalize_ascii(str) do
    str
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/[^\x20-\x7E]/u, "")
    |> String.trim()
    |> case do
      "" -> "ROLEZINHO"
      other -> other
    end
  end

  # CRC16-CCITT-FALSE (poly 0x1021, init 0xFFFF), used by PIX BR Code.
  defp crc16(binary) when is_binary(binary) do
    crc =
      binary
      |> :binary.bin_to_list()
      |> Enum.reduce(0xFFFF, fn byte, crc ->
        crc = bxor(crc, byte <<< 8)

        Enum.reduce(1..8, crc, fn _, acc ->
          if band(acc, 0x8000) != 0 do
            band(bxor(acc <<< 1, 0x1021), 0xFFFF)
          else
            band(acc <<< 1, 0xFFFF)
          end
        end)
      end)

    crc
    |> Integer.to_string(16)
    |> String.pad_leading(4, "0")
    |> String.upcase()
  end
end

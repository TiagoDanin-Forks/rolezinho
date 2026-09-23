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

  @types [:phone, :cpf, :cnpj, :email, :random]

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

  @doc """
  Identifies which of the five DICT key types a string is, and returns it in the
  exact form the BR Code expects.

  Format matters here beyond tidiness: the payload carries the key verbatim, and
  a key the payer's bank cannot resolve produces a QR that scans and then fails.
  Each type has one canonical shape — phone with `+55`, CPF and CNPJ as digits
  only, a random key with its hyphens — so the same key typed three different
  ways still reaches the same account.

  This validates *shape*, not ownership: whether the key belongs to the
  organizer is between them and whoever pays (RN-10).

  ## Examples

      iex> Rolezinho.Pix.classify("(91) 98493-3238")
      {:ok, :phone, "+5591984933238"}

      iex> Rolezinho.Pix.classify("123.456.789-00")
      {:ok, :cpf, "12345678900"}

      iex> Rolezinho.Pix.classify("nope")
      :error
  """
  @spec classify(String.t() | nil) ::
          {:ok, :phone | :cpf | :cnpj | :email | :random, String.t()} | :error
  def classify(nil), do: :error

  def classify(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" -> :error
      email?(trimmed) -> {:ok, :email, String.downcase(trimmed)}
      random_key?(trimmed) -> {:ok, :random, String.downcase(trimmed)}
      true -> classify_digits(trimmed)
    end
  end

  @doc """
  Returns the canonical form of a key, or `nil` when it is not a valid one.

  ## Examples

      iex> Rolezinho.Pix.normalize("91984933238")
      "+5591984933238"
  """
  @spec normalize(String.t() | nil) :: String.t() | nil
  def normalize(value) do
    case classify(value) do
      {:ok, _type, canonical} -> canonical
      :error -> nil
    end
  end

  @doc "The five DICT key types, in the order to present them on the form."
  @spec types() :: [atom()]
  def types, do: @types

  @doc """
  Human label for each DICT key type, in Portuguese, for form option rendering.
  """
  @spec type_label(atom()) :: String.t()
  def type_label(:phone), do: "Celular"
  def type_label(:cpf), do: "CPF"
  def type_label(:cnpj), do: "CNPJ"
  def type_label(:email), do: "E-mail"
  def type_label(:random), do: "Aleatória"

  @doc """
  Canonicalizes a raw key against an explicitly chosen type.

  Unlike `classify/1`, this makes no guesses — the caller decided the key is
  a phone (or CPF, etc.) and this returns the canonical form for that type,
  or `:error` when the value cannot be a valid instance of that type.

  A bare 11-digit string here becomes a phone when the caller says
  `:phone`, and a CPF when the caller says `:cpf`. That is the whole point:
  the organizer picks; the app trusts.

  ## Examples

      iex> Rolezinho.Pix.canonicalize("91984933238", :phone)
      {:ok, "+5591984933238"}

      iex> Rolezinho.Pix.canonicalize("12345678900", :cpf)
      {:ok, "12345678900"}

      iex> Rolezinho.Pix.canonicalize("not-a-key", :email)
      :error
  """
  @spec canonicalize(String.t() | nil, atom()) :: {:ok, String.t()} | :error
  def canonicalize(value, type) when type in @types and is_binary(value) do
    canonicalize_for(String.trim(value), type)
  end

  def canonicalize(_value, _type), do: :error

  defp canonicalize_for("", _type), do: :error

  defp canonicalize_for(value, :email) do
    if email?(value), do: {:ok, String.downcase(value)}, else: :error
  end

  defp canonicalize_for(value, :random) do
    if random_key?(value), do: {:ok, String.downcase(value)}, else: :error
  end

  defp canonicalize_for(value, :phone) do
    digits = Regex.replace(~r/\D/, value, "")

    cond do
      String.starts_with?(value, "+") and byte_size(digits) in [12, 13] ->
        {:ok, "+" <> digits}

      String.starts_with?(digits, "55") and byte_size(digits) == 13 ->
        {:ok, "+" <> digits}

      byte_size(digits) in [10, 11] ->
        {:ok, "+55" <> digits}

      true ->
        :error
    end
  end

  defp canonicalize_for(value, :cpf) do
    digits = Regex.replace(~r/\D/, value, "")
    if byte_size(digits) == 11, do: {:ok, digits}, else: :error
  end

  defp canonicalize_for(value, :cnpj) do
    digits = Regex.replace(~r/\D/, value, "")
    if byte_size(digits) == 14, do: {:ok, digits}, else: :error
  end

  @doc """
  Formats a key for display, keeping it recognizable to whoever typed it.

  A phone reads as a phone and a CPF as a CPF; e-mail and random keys are
  already in the form people recognize.
  """
  @spec display(String.t() | nil) :: String.t() | nil
  def display(value) do
    case classify(value) do
      {:ok, :phone, canonical} -> format_phone(canonical)
      {:ok, :cpf, digits} -> format_cpf(digits)
      {:ok, :cnpj, digits} -> format_cnpj(digits)
      {:ok, _type, canonical} -> canonical
      :error -> nil
    end
  end

  @doc """
  Formats a key for display against an explicitly chosen type.

  Companion of `canonicalize/2`, and the reason it exists is the same:
  `display/1` guesses from the string's shape, so a bare 11-digit phone
  gets formatted as a CPF ("123.456.789-00") because that is what the
  guesser resolves to. When the caller *knows* the type, this uses it
  directly and produces the correct format.

  Returns the canonical value (unformatted) when the type is known but
  the value cannot be canonicalized — the goal is to never crash the
  render, only to display what we have.
  """
  @spec display_as(String.t() | nil, atom()) :: String.t() | nil
  def display_as(value, type) when type in @types and is_binary(value) do
    case canonicalize(value, type) do
      {:ok, canonical} -> format_for(canonical, type)
      :error -> nil
    end
  end

  def display_as(_value, _type), do: nil

  defp format_for(canonical, :phone), do: format_phone(canonical)
  defp format_for(canonical, :cpf), do: format_cpf(canonical)
  defp format_for(canonical, :cnpj), do: format_cnpj(canonical)
  defp format_for(canonical, _other), do: canonical

  defp classify_digits(value) do
    digits = Regex.replace(~r/\D/, value, "")

    cond do
      # A phone is the only type written with a leading +, and the only one this
      # project rewrites: 10 or 11 local digits gain the country code.
      String.starts_with?(value, "+") and byte_size(digits) in [12, 13] ->
        {:ok, :phone, "+" <> digits}

      String.starts_with?(digits, "55") and byte_size(digits) == 13 ->
        {:ok, :phone, "+" <> digits}

      byte_size(digits) in [10, 11] and phone_shaped?(value) ->
        {:ok, :phone, "+55" <> digits}

      byte_size(digits) == 11 ->
        {:ok, :cpf, digits}

      byte_size(digits) == 14 ->
        {:ok, :cnpj, digits}

      true ->
        :error
    end
  end

  # 11 digits is ambiguous: it is both a mobile number and a CPF. Punctuation
  # decides — "(91) 98493-3238" is a phone, "123.456.789-00" is a CPF — and a
  # bare 11-digit string falls through to CPF, which is the safer default since
  # a wrong phone would be someone else's real number.
  defp phone_shaped?(value), do: String.contains?(value, ["(", ")", " "])

  defp email?(value) do
    Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/u, value) and byte_size(value) <= 77
  end

  defp random_key?(value) do
    Regex.match?(~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, value)
  end

  defp format_cpf(<<a::binary-3, b::binary-3, c::binary-3, d::binary-2>>) do
    "#{a}.#{b}.#{c}-#{d}"
  end

  defp format_cpf(digits), do: digits

  defp format_cnpj(<<a::binary-2, b::binary-3, c::binary-3, d::binary-4, e::binary-2>>) do
    "#{a}.#{b}.#{c}/#{d}-#{e}"
  end

  defp format_cnpj(digits), do: digits

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

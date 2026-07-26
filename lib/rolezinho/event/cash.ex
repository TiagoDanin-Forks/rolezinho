defmodule Rolezinho.Event.Cash do
  @moduledoc """
  What the event is owed and by whom (RN-15).

  The app never touches the money: a check is a statement by the person who says
  they paid, not a confirmation from a bank (RN-10, RN-11). So this counts
  declarations, and every number here inherits that — "recebido" means "declared
  as paid", and the organizer is the one who reconciles it against what actually
  arrived.

  Its reason to exist is the awkward part of organizing: chasing four people
  individually is what makes someone stop organizing. A list of who still owes,
  and one message addressed to all of them, is the whole feature.
  """

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee

  @type summary :: %{
          expected_cents: non_neg_integer(),
          received_cents: non_neg_integer(),
          missing_cents: non_neg_integer(),
          debtors: [String.t()],
          paid_count: non_neg_integer(),
          total_count: non_neg_integer()
        }

  @doc """
  Summarizes what the event expects, what has been declared, and who is missing.

  Counts only filled slots: an empty position owes nothing. The waiting list is
  excluded — those people have no place yet, so charging them would be charging
  for something they did not get.

  ## Examples

      iex> summary = Rolezinho.Event.Cash.summary(event)
      iex> summary.debtors
      ["Roberta", "Henrique"]
  """
  @spec summary(Event.t()) :: summary()
  def summary(%Event{} = event) do
    attendees = filled(event.main_list)
    price = event.price_cents || 0

    {paid, unpaid} = Enum.split_with(attendees, & &1.paid)

    %{
      expected_cents: price * length(attendees),
      received_cents: price * length(paid),
      missing_cents: price * length(unpaid),
      debtors: Enum.map(unpaid, & &1.name),
      paid_count: length(paid),
      total_count: length(attendees)
    }
  end

  @doc """
  Returns true when there is an amount to settle at all.

  A free event has nothing to chase, and neither does one where everybody has
  already declared payment — in both cases the reminder UI is noise.
  """
  @spec outstanding?(Event.t()) :: boolean()
  def outstanding?(%Event{} = event) do
    summary = summary(event)
    summary.missing_cents > 0 and summary.debtors != []
  end

  @doc """
  Builds the message that chases everyone who still owes, in one go.

  Names them all in a single text rather than producing one message per person:
  the group chat is where this lands, and four separate nudges read as nagging
  where one list reads as bookkeeping.

  Returns `nil` when there is nothing to charge, so callers do not have to
  special-case an empty reminder.

  ## Examples

      iex> Rolezinho.Event.Cash.reminder_text(event)
      "Vôlei · faltou o Pix de: Roberta, Henrique\\nR$ 15 cada · Pix 91984933238"
  """
  @spec reminder_text(Event.t()) :: String.t() | nil
  def reminder_text(%Event{} = event) do
    case summary(event) do
      %{debtors: []} ->
        nil

      %{debtors: debtors} ->
        [
          "#{String.trim(event.title)} · faltou o Pix de: #{Enum.join(debtors, ", ")}",
          amount_line(event)
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join("\n")
    end
  end

  @doc """
  Formats an amount in cents the way the group writes it.

  Whole values lose the decimals — "R$ 15", not "R$ 15,00" — because that is how
  someone says it out loud, and the extra zeros read as an invoice.

  ## Examples

      iex> Rolezinho.Event.Cash.format_amount(1500)
      "R$ 15"

      iex> Rolezinho.Event.Cash.format_amount(1550)
      "R$ 15,50"
  """
  @spec format_amount(non_neg_integer() | nil) :: String.t() | nil
  def format_amount(nil), do: nil
  def format_amount(0), do: nil

  def format_amount(cents) when is_integer(cents) do
    reais = div(cents, 100)

    case rem(cents, 100) do
      0 -> "R$ #{reais}"
      remainder -> "R$ #{reais},#{String.pad_leading(to_string(remainder), 2, "0")}"
    end
  end

  defp amount_line(%Event{price_cents: price, pix_key: key}) do
    parts =
      [
        price |> format_amount() |> maybe_suffix(" cada"),
        key && key != "" && "Pix #{key}"
      ]
      |> Enum.filter(&is_binary/1)

    case parts do
      [] -> nil
      parts -> Enum.join(parts, " · ")
    end
  end

  defp maybe_suffix(nil, _suffix), do: nil
  defp maybe_suffix(value, suffix), do: value <> suffix

  defp filled(list) do
    Enum.filter(list, fn
      %Attendee{name: name} -> String.trim(name) != ""
      _ -> false
    end)
  end
end

defmodule Rolezinho.Event.Policy do
  @moduledoc """
  Who may do what to an event and its rows.

  This is the permission matrix from the product spec, in one place, so a screen
  never decides for itself. Hiding a button is presentation; these functions are
  the decision, and a privileged `handle_event` has to call one of them even
  when the template already hid the control — a socket message can be sent
  without the button existing.

  The roles are ordered: `:admin` (environment-wide support bypass) can do
  whatever `:organizer` can, which can do whatever a `:participant` can on their
  own row. A `:visitor` may only read and join.

  | Action              | Visitor | Participant | Organizer |
  |---------------------|---------|-------------|-----------|
  | join a list         | yes     | yes         | yes       |
  | mark own payment    | no      | own row     | any row   |
  | mark another's      | no      | no          | yes       |
  | leave the list      | no      | own row     | any row   |
  | remove someone      | no      | no          | yes       |
  | promote from wait   | no      | no          | yes       |
  | edit details        | no      | no          | yes       |
  | close the event     | no      | no          | yes       |
  """

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee

  @type role :: :visitor | :participant | :organizer | :admin

  @doc """
  Resolves the caller's role for this event.

  `admin?` is the environment-wide bypass; `organizer?` means the browser holds
  this event's token. Holding a row makes someone a participant, but the row
  itself still decides which row they may touch.
  """
  @spec role(Event.t(), keyword()) :: role()
  def role(%Event{} = event, opts) do
    cond do
      Keyword.get(opts, :admin?, false) -> :admin
      Keyword.get(opts, :organizer?, false) -> :organizer
      holds_a_row?(event, Keyword.get(opts, :participant_id)) -> :participant
      true -> :visitor
    end
  end

  @doc """
  Returns true when the caller may flip the paid check on `attendee`.

  RN-12: a participant only ever marks their own row — the check is a statement
  about money they say they sent, so nobody else gets to make it for them.
  RN-13: the organizer may mark anyone, being the one who sees the money arrive.
  """
  @spec can_toggle_paid?(Event.t(), Attendee.t(), keyword()) :: boolean()
  def can_toggle_paid?(%Event{} = event, %Attendee{} = attendee, opts) do
    case role(event, opts) do
      role when role in [:organizer, :admin] -> true
      :participant -> Attendee.owned_by?(attendee, Keyword.get(opts, :participant_id))
      :visitor -> false
    end
  end

  @doc """
  Returns true when the caller may take `attendee` off the list.

  RN-21: a participant removes only themselves. Confirmation is still required
  either way (RN-22), but that is the screen's job, not this one's.
  """
  @spec can_remove?(Event.t(), Attendee.t(), keyword()) :: boolean()
  def can_remove?(%Event{} = event, %Attendee{} = attendee, opts) do
    case role(event, opts) do
      role when role in [:organizer, :admin] -> true
      :participant -> Attendee.owned_by?(attendee, Keyword.get(opts, :participant_id))
      :visitor -> false
    end
  end

  @doc """
  Returns true when the caller may edit the event itself.

  RN-23: title, location, time, price and the Pix key belong to the organizer.
  """
  @spec can_edit?(Event.t(), keyword()) :: boolean()
  def can_edit?(%Event{} = event, opts), do: role(event, opts) in [:organizer, :admin]

  @doc """
  Returns true when the caller may promote someone from the waiting list.

  RN-31: promotion is a decision, never automatic — an open slot does not pull
  the queue by itself.
  """
  @spec can_promote?(Event.t(), keyword()) :: boolean()
  def can_promote?(%Event{} = event, opts), do: role(event, opts) in [:organizer, :admin]

  @doc """
  Returns true when someone may still join.

  Invariant 6: a closed event accepts nobody, whoever is asking. `payments_only`
  keeps the same meaning it has today — signups shut, payments still tracked —
  and the organizer stays able to add people by hand.
  """
  @spec can_join?(Event.t(), keyword()) :: boolean()
  def can_join?(%Event{status: :done}, _opts), do: false

  def can_join?(%Event{} = event, opts) do
    not Event.locked_signups?(event) or role(event, opts) in [:organizer, :admin]
  end

  defp holds_a_row?(_event, nil), do: false
  defp holds_a_row?(_event, ""), do: false

  defp holds_a_row?(%Event{} = event, participant_id) do
    event
    |> all_attendees()
    |> Enum.any?(&Attendee.owned_by?(&1, participant_id))
  end

  defp all_attendees(%Event{main_list: main, wait_list: wait}) do
    Enum.filter(main ++ wait, &match?(%Attendee{}, &1))
  end
end

defmodule RolezinhoWeb.Components.UI.DateTimeField do
  @moduledoc """
  Date, start time, and end time for an event.

  Uses native date/time inputs so the phone opens its own picker — typing a date
  on a phone keyboard is the slowest way to enter one. Real values rather than
  free text is what lets the listing sort chronologically and the `.ics` carry a
  correct timestamp.
  """
  use Phoenix.Component

  @doc """
  Renders the three fields as one row.

  ## Examples

      <.date_time_field date="2026-07-15" starts_at="19:00" ends_at="21:00" />
  """
  attr :date, :string, default: nil
  attr :starts_at, :string, default: nil
  attr :ends_at, :string, default: nil
  attr :date_name, :string, default: "date"
  attr :starts_at_name, :string, default: "starts_at"
  attr :ends_at_name, :string, default: "ends_at"
  attr :date_label, :string, default: "Date"
  attr :starts_at_label, :string, default: "Start"
  attr :ends_at_label, :string, default: "End"
  attr :class, :any, default: nil

  def date_time_field(assigns) do
    ~H"""
    <div class={["flex gap-2", @class]}>
      <label class="flex-[1.4]">
        <span class="mb-1 block text-[10px] font-bold text-ink/45">{@date_label}</span>
        <input
          type="date"
          name={@date_name}
          value={@date}
          class="w-full rounded-row border border-ink/12 bg-base-100 px-3 py-2.5 text-[13px] font-bold text-ink outline-none focus:border-accent focus:ring-2 focus:ring-accent/20"
        />
      </label>
      <label class="flex-1">
        <span class="mb-1 block text-[10px] font-bold text-ink/45">{@starts_at_label}</span>
        <input
          type="time"
          name={@starts_at_name}
          value={@starts_at}
          class="w-full rounded-row border border-ink/12 bg-base-100 px-3 py-2.5 text-[13px] font-bold text-ink outline-none focus:border-accent focus:ring-2 focus:ring-accent/20"
        />
      </label>
      <label class="flex-1">
        <span class="mb-1 block text-[10px] font-bold text-ink/45">{@ends_at_label}</span>
        <input
          type="time"
          name={@ends_at_name}
          value={@ends_at}
          class="w-full rounded-row border border-ink/12 bg-base-100 px-3 py-2.5 text-[13px] font-bold text-ink outline-none focus:border-accent focus:ring-2 focus:ring-accent/20"
        />
      </label>
    </div>
    """
  end
end

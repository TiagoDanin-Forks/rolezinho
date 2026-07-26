defmodule RolezinhoWeb.Components.UI.ProgressBar do
  @moduledoc """
  How full a list is (`progress_bar/1`) and how to read the checks
  (`payment_legend/1`).

  The legend is not optional: any screen showing the paid check needs it above
  the first list. A check on its own does not communicate whether it means
  "paid" or "confirmed".
  """
  use Phoenix.Component

  @doc """
  Renders the occupancy bar of a list.

  ## Examples

      <.progress_bar filled={17} capacity={18} />
      <.progress_bar filled={3} capacity={10} label="Main list" />
  """
  attr :filled, :integer, required: true
  attr :capacity, :integer, required: true
  attr :label, :string, default: nil, doc: "when given, renders the header row with the counter"
  attr :class, :any, default: nil

  def progress_bar(assigns) do
    assigns = assign(assigns, :percent, percent(assigns.filled, assigns.capacity))

    ~H"""
    <div class={@class}>
      <div :if={@label} class="flex items-center justify-between">
        <span class="text-[13px] font-bold">{@label}</span>
        <span class="text-[11px] font-semibold text-ink/55">{@filled}/{@capacity}</span>
      </div>
      <div
        class={["h-[5px] overflow-hidden rounded-full bg-ink/[0.08]", @label && "mt-2"]}
        role="progressbar"
        aria-valuenow={@filled}
        aria-valuemin="0"
        aria-valuemax={@capacity}
        aria-label={@label || "List occupancy"}
      >
        <div class="h-full rounded-full bg-accent transition-[width]" style={"width: #{@percent}%"} />
      </div>
    </div>
    """
  end

  @doc """
  Renders the legend that explains the paid check.

  ## Examples

      <.payment_legend />
  """
  attr :paid_label, :string, default: "already paid"
  attr :unpaid_label, :string, default: "has not paid yet"
  attr :class, :any, default: nil

  def payment_legend(assigns) do
    ~H"""
    <div class={[
      "flex flex-wrap items-center gap-2 text-[11px] font-semibold text-ink/55",
      @class
    ]}>
      <span class="inline-flex size-4 items-center justify-center rounded-full bg-accent text-[9px] text-accent-content">
        ✓
      </span>
      <span>{@paid_label}</span>
      <span class="ml-1.5 inline-block size-4 rounded-full border-[1.5px] border-ink/15" />
      <span>{@unpaid_label}</span>
    </div>
    """
  end

  defp percent(_filled, capacity) when capacity <= 0, do: 0

  defp percent(filled, capacity) do
    filled |> max(0) |> min(capacity) |> Kernel.*(100) |> div(capacity)
  end
end

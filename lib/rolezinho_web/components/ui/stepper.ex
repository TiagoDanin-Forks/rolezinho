defmodule RolezinhoWeb.Components.UI.Stepper do
  @moduledoc """
  A numeric stepper: how many people, how big the list.

  Preferred over a number input on a phone — no keyboard, and the value is
  changed with the thumb. The buttons disable at the bounds instead of silently
  clamping, so the limit is visible rather than surprising.
  """
  use Phoenix.Component

  import RolezinhoWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders the stepper.

  ## Examples

      <.stepper label="How many people?" value={@qty} dec="dec_qty" inc="inc_qty" />
      <.stepper
        label="Slots"
        hint="Main list"
        value={@capacity}
        min={1}
        max={60}
        dec="shrink"
        inc="grow"
      />
  """
  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :value, :integer, required: true
  attr :min, :integer, default: 1
  attr :max, :integer, default: 9
  attr :dec, :any, required: true, doc: "phx-click for the decrement"
  attr :inc, :any, required: true, doc: "phx-click for the increment"
  attr :class, :any, default: nil

  def stepper(assigns) do
    ~H"""
    <div class={[
      "flex items-center justify-between gap-3 rounded-cta",
      "border border-ink/8 bg-white px-3.5 py-2.5",
      @class
    ]}>
      <div>
        <div class="text-[13px] font-bold">{@label}</div>
        <div :if={@hint} class="mt-px text-[11px] text-ink/55">{@hint}</div>
      </div>
      <div class="flex items-center gap-3.5">
        <button
          type="button"
          phx-click={@dec}
          disabled={@value <= @min}
          aria-label="Decrease"
          class={[
            "inline-flex size-11 items-center justify-center rounded-full",
            "bg-ink/[0.08] text-ink transition",
            "disabled:opacity-30 disabled:pointer-events-none",
            "active:scale-[0.97] motion-reduce:active:scale-100"
          ]}
        >
          <.icon name="tabler-minus" class="size-4" />
        </button>
        <output class="min-w-4 text-center text-base font-extrabold">{@value}</output>
        <button
          type="button"
          phx-click={@inc}
          disabled={@value >= @max}
          aria-label="Increase"
          class={[
            "inline-flex size-11 items-center justify-center rounded-full",
            "bg-ink text-ink-content transition",
            "disabled:opacity-30 disabled:pointer-events-none",
            "active:scale-[0.97] motion-reduce:active:scale-100"
          ]}
        >
          <.icon name="tabler-plus" class="size-4" />
        </button>
      </div>
    </div>
    """
  end
end

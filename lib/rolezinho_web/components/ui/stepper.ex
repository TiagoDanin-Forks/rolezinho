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
        <div :if={@hint} class="mt-px text-[11px] text-muted">{@hint}</div>
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

  @doc """
  The same control inside a plain form, where the count travels as a field.

  Counting people is not a decision the server needs to hear about until the
  form is submitted, so this one keeps its state on the client. That also means
  it works in a form that posts rather than one bound to a LiveView.

  ## Examples

      <.form_stepper name="qty" label="Quantas pessoas?" hint="Você + acompanhantes" />
  """
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :hint, :string, default: nil
  attr :value, :integer, default: 1
  attr :min, :integer, default: 1
  attr :max, :integer, default: 9
  attr :class, :any, default: nil

  def form_stepper(assigns) do
    ~H"""
    <div
      id={"stepper-" <> @name}
      phx-hook=".FormStepper"
      data-min={@min}
      data-max={@max}
      class={[
        "flex items-center justify-between gap-3 rounded-cta",
        "border border-ink/8 bg-white px-3.5 py-2.5",
        @class
      ]}
    >
      <div>
        <div class="text-[13px] font-bold">{@label}</div>
        <div :if={@hint} class="mt-px text-[11px] text-muted">{@hint}</div>
      </div>
      <div class="flex items-center gap-3.5">
        <button
          type="button"
          data-step="-1"
          aria-label="Menos uma pessoa"
          class="inline-flex size-11 items-center justify-center rounded-full bg-ink/[0.08] text-ink transition active:scale-[0.97] disabled:pointer-events-none disabled:opacity-30 motion-reduce:active:scale-100"
        >
          <.icon name="tabler-minus" class="size-4" />
        </button>
        <output data-display class="min-w-4 text-center text-base font-extrabold">{@value}</output>
        <input type="hidden" name={@name} value={@value} data-field />
        <button
          type="button"
          data-step="1"
          aria-label="Mais uma pessoa"
          class="inline-flex size-11 items-center justify-center rounded-full bg-ink text-ink-content transition active:scale-[0.97] disabled:pointer-events-none disabled:opacity-30 motion-reduce:active:scale-100"
        >
          <.icon name="tabler-plus" class="size-4" />
        </button>
      </div>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".FormStepper">
      export default {
        mounted() {
          const field = this.el.querySelector("[data-field]")
          const display = this.el.querySelector("[data-display]")
          const min = Number(this.el.dataset.min)
          const max = Number(this.el.dataset.max)

          const render = () => {
            const value = Number(field.value)
            display.textContent = value
            this.el.querySelectorAll("[data-step]").forEach((button) => {
              const next = value + Number(button.dataset.step)
              button.disabled = next < min || next > max
            })
          }

          this.el.querySelectorAll("[data-step]").forEach((button) => {
            button.addEventListener("click", () => {
              const next = Number(field.value) + Number(button.dataset.step)
              if (next >= min && next <= max) { field.value = next; render() }
            })
          })

          render()
        }
      }
    </script>
    """
  end
end

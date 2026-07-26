defmodule RolezinhoWeb.Components.UI.SwipeActions do
  @moduledoc """
  Row actions revealed by dragging it to the left.

  An organizer going through eighteen rows needs a gesture, not a small target
  repeated eighteen times. The gesture is an accelerator and never the only way
  in: the same actions stay reachable as buttons once the row is open, and the
  row itself keeps its own controls, so keyboard and screen-reader users are not
  cut off from anything.

  The destructive action goes last, furthest from the resting position, so an
  overshoot lands on the safe one. Confirmation still belongs to the caller —
  removal always asks (RN-22).
  """
  use Phoenix.Component

  @doc """
  Renders the row with its hidden actions.

  ## Examples

      <.swipe_actions>
        <:action label="Paid" tone="accent" on_click={JS.push("toggle_paid")} />
        <:action label="Remove" tone="danger" on_click={JS.push("ask_remove")} />
        <div class="px-3.5 py-3 text-[13px] font-semibold">Henrique</div>
      </.swipe_actions>
  """
  attr :class, :any, default: nil
  attr :value, :string, default: nil, doc: "sent as phx-value-id on every action"

  slot :action, doc: "at most two; the destructive one goes last" do
    attr :label, :string, required: true
    attr :tone, :string, values: ~w(accent danger ink)
    attr :on_click, :any
  end

  slot :inner_block, required: true

  def swipe_actions(assigns) do
    ~H"""
    <div
      id={"swipe-" <> (@value || "row")}
      phx-hook=".SwipeActions"
      class={["relative overflow-hidden rounded-row bg-base-100", @class]}
    >
      <div class="absolute inset-y-0 right-0 flex" data-actions>
        <button
          :for={action <- @action}
          type="button"
          phx-click={action[:on_click]}
          phx-value-id={@value}
          tabindex="-1"
          aria-hidden="true"
          class={[
            "w-[62px] text-[10px] font-extrabold uppercase tracking-wide",
            tone_classes(action[:tone] || "ink")
          ]}
        >
          {action.label}
        </button>
      </div>

      <div
        class="relative bg-base-100 transition-transform duration-200 will-change-transform"
        data-surface
      >
        {render_slot(@inner_block)}
      </div>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".SwipeActions">
      export default {
        mounted() {
          const surface = this.el.querySelector("[data-surface]")
          const actions = this.el.querySelector("[data-actions]")
          let startX = 0, startY = 0, dragging = false, open = false

          const width = () => actions.offsetWidth
          const move = (px) => { surface.style.transform = `translateX(${px}px)` }
          const settle = (isOpen) => {
            open = isOpen
            surface.style.transition = "transform 200ms"
            move(isOpen ? -width() : 0)
            // Actions are only reachable by tab or screen reader while open,
            // so the closed row does not announce buttons nobody can see.
            actions.querySelectorAll("button").forEach((b) => {
              b.tabIndex = isOpen ? 0 : -1
              b.setAttribute("aria-hidden", String(!isOpen))
            })
          }

          this.el.addEventListener("touchstart", (e) => {
            startX = e.touches[0].clientX
            startY = e.touches[0].clientY
            dragging = true
            surface.style.transition = "none"
          }, { passive: true })

          this.el.addEventListener("touchmove", (e) => {
            if (!dragging) return
            const dx = e.touches[0].clientX - startX
            const dy = e.touches[0].clientY - startY
            // A mostly-vertical drag is the page scrolling, not a row swipe.
            if (Math.abs(dy) > Math.abs(dx)) { dragging = false; settle(open); return }
            const base = open ? -width() : 0
            move(Math.min(0, Math.max(-width(), base + dx)))
          }, { passive: true })

          this.el.addEventListener("touchend", (e) => {
            if (!dragging) return
            dragging = false
            const dx = e.changedTouches[0].clientX - startX
            settle(dx < -width() / 2 ? true : (dx > width() / 2 ? false : open))
          })

          settle(false)
        }
      }
    </script>
    """
  end

  defp tone_classes("accent"), do: "bg-accent text-accent-content"
  defp tone_classes("danger"), do: "bg-danger text-danger-content"
  defp tone_classes("ink"), do: "bg-ink text-ink-content"
end

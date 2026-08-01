defmodule RolezinhoWeb.Components.UI.Coachmark do
  @moduledoc """
  A one-time hint attached to a control whose meaning is not self-evident.

  Dismissal is remembered in `localStorage` under `seen_key`, so the hint is
  shown once per device and never again. Kept deliberately rare — at most one
  per screen and three in the whole app — because a hint that appears every time
  stops being read and starts being noise.

  The visibility decision is made on the client: the server does not know what
  this device has already seen, and rendering it hidden avoids a flash of the
  hint for people who dismissed it long ago.
  """
  use Phoenix.Component

  @doc """
  Renders the hint.

  ## Examples

      <.coachmark seen_key="paid-check">
        Tap here once you have paid. Only you can mark your own.
      </.coachmark>
  """
  attr :seen_key, :string, required: true, doc: "localStorage key identifying this hint"
  attr :dismiss_label, :string, default: "Got it"
  attr :class, :any, default: nil

  slot :inner_block, required: true

  def coachmark(assigns) do
    ~H"""
    <div
      id={"coachmark-" <> @seen_key}
      phx-hook=".Coachmark"
      data-seen-key={@seen_key}
      hidden
      class={["flex items-center gap-2.5 rounded-row bg-ink px-3 py-2.5", @class]}
      role="note"
    >
      <p class="flex-1 text-[11.5px] leading-snug text-ink-content">
        {render_slot(@inner_block)}
      </p>
      <button
        type="button"
        data-dismiss
        class="-my-3 shrink-0 py-3 text-[10px] font-bold uppercase tracking-wide text-accent focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      >
        {@dismiss_label}
      </button>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".Coachmark">
      const storageKey = (el) => `rolezinho:coachmark:${el.dataset.seenKey}`

      export default {
        mounted() {
          // localStorage throws in Safari private mode; a hint is not worth
          // breaking the page over, so failing to read it just shows the hint.
          let seen = false
          try { seen = localStorage.getItem(storageKey(this.el)) === "1" } catch (_) {}
          if (!seen) { this.el.hidden = false }

          this.el.querySelector("[data-dismiss]").addEventListener("click", () => {
            this.el.hidden = true
            try { localStorage.setItem(storageKey(this.el), "1") } catch (_) {}
          })
        }
      }
    </script>
    """
  end
end

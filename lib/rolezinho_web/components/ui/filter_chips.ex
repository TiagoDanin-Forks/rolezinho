defmodule RolezinhoWeb.Components.UI.FilterChips do
  @moduledoc """
  A horizontal, single-choice filter row.

  Scrolls sideways instead of wrapping: with several categories, a wrapping row
  pushes the content below it down and shifts the whole screen. The selected
  state lives in `aria-checked`, so the styling follows from the attribute
  rather than from a conditional class string.
  """
  use Phoenix.Component

  @doc """
  Renders the filter row.

  ## Examples

      <.filter_chips value={@category} on_select={JS.push("filter")}>
        <:chip id="all" label="All" />
        <:chip id="sport" label="Sport" />
        <:chip id="cowork" label="Coworking" />
      </.filter_chips>
  """
  attr :value, :string, required: true, doc: "id of the selected chip"
  attr :on_select, :any, default: nil, doc: "JS command or event name, receives phx-value-id"
  attr :label, :string, default: "Filter by category"
  attr :class, :any, default: nil

  slot :chip, required: true do
    attr :id, :string, required: true
    attr :label, :string, required: true
  end

  def filter_chips(assigns) do
    ~H"""
    <div
      class={["-mx-1 flex gap-1.5 overflow-x-auto px-1 [scrollbar-width:none]", @class]}
      role="radiogroup"
      aria-label={@label}
    >
      <button
        :for={chip <- @chip}
        type="button"
        role="radio"
        aria-checked={to_string(chip.id == @value)}
        phx-click={@on_select}
        phx-value-id={chip.id}
        class={[
          "whitespace-nowrap rounded-row bg-ink/[0.08] px-3.5 py-2.5 text-xs font-bold text-muted",
          "aria-checked:bg-accent aria-checked:text-accent-content",
          "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        ]}
      >
        {chip.label}
      </button>
    </div>
    """
  end
end

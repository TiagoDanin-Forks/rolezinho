defmodule RolezinhoWeb.Components.UI.ToggleChip do
  @moduledoc """
  A binary toggle rendered as a chip: required/optional, include the link,
  include the password.

  On means orange with white text — the same "active state" role orange carries
  everywhere else in the system.
  """
  use Phoenix.Component

  @doc """
  Renders the toggle chip.

  ## Examples

      <.toggle_chip on={@required} click="toggle_required" label_on="Required" label_off="Optional" />
      <.toggle_chip on={@include_link} click="toggle_link" label_on="Include link" />
  """
  attr :on, :boolean, required: true
  attr :click, :any, required: true
  attr :label_on, :string, required: true

  attr :label_off, :string,
    default: nil,
    doc: "defaults to label_on when the label does not change"

  attr :uppercase, :boolean, default: false
  attr :class, :any, default: nil

  def toggle_chip(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@click}
      aria-pressed={to_string(@on)}
      class={[
        "min-h-11 flex-1 rounded-cta px-3 py-2.5 text-[11px] font-bold transition",
        @uppercase && "uppercase tracking-wide",
        if(@on,
          do: "bg-accent text-accent-content",
          else: "bg-ink/[0.08] text-ink/55 hover:bg-ink/[0.12]"
        ),
        @class
      ]}
    >
      {if @on, do: @label_on, else: @label_off || @label_on}
    </button>
    """
  end
end

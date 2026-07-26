defmodule RolezinhoWeb.Components.UI.StatusPill do
  @moduledoc """
  The state of an event, as a pill.

  Paired source: the tones map to `Rolezinho.Event` statuses plus the two derived
  states (`open`/`full`) that come from comparing the list against its capacity.
  A new event status requires a tone here.
  """
  use Phoenix.Component

  @doc """
  Renders the status pill.

  ## Examples

      <.status_pill tone="open">Slots open</.status_pill>
      <.status_pill tone="full">List full</.status_pill>
      <.status_pill tone="done">Closed</.status_pill>
      <.status_pill tone="debt">Pix pending</.status_pill>
  """
  attr :tone, :string, default: "open", values: ~w(open full done debt payments_only)
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def status_pill(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex items-center rounded-row px-3 py-[7px] text-[11px] font-bold",
        tone_classes(@tone),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp tone_classes("open"), do: "bg-tint text-accent-ink"
  defp tone_classes("full"), do: "bg-ink text-ink-content"
  defp tone_classes("done"), do: "bg-ink/[0.08] text-ink/55"
  defp tone_classes("debt"), do: "bg-danger text-danger-content"
  defp tone_classes("payments_only"), do: "bg-warning text-warning-content"
end

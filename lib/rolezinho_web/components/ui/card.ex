defmodule RolezinhoWeb.Components.UI.Card do
  @moduledoc """
  The content block everything else sits inside.

  A card is a white surface on the warm cream canvas with a hairline border and
  no resting shadow — the canvas contrast is what gives it shape (see
  `DESIGN.md`, section 8).
  """
  use Phoenix.Component

  @doc """
  Renders a card.

  ## Examples

      <.card>
        <p>Anything.</p>
      </.card>

      <.card padding="lg" radius="panel">...</.card>
  """
  attr :padding, :string, default: "md", values: ~w(none sm md lg)
  attr :radius, :string, default: "box", values: ~w(field box panel)
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div
      class={[
        "border border-ink/8 bg-white text-ink",
        padding_classes(@padding),
        radius_classes(@radius),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders the recessed well used inside a card to frame a demo or a grouped zone.

  ## Examples

      <.well>
        <.action_button>Join the list</.action_button>
      </.well>
  """
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def well(assigns) do
    ~H"""
    <div class={["rounded-cta bg-surface p-[14px]", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp padding_classes("none"), do: nil
  defp padding_classes("sm"), do: "p-3"
  defp padding_classes("md"), do: "p-4"
  defp padding_classes("lg"), do: "p-5"

  defp radius_classes("field"), do: "rounded-cta"
  defp radius_classes("box"), do: "rounded-card"
  defp radius_classes("panel"), do: "rounded-sheet"
end

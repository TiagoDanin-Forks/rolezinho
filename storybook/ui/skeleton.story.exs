defmodule Storybook.UI.Skeleton do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.Skeleton.skeleton/1

  def template do
    """
    <div class="max-w-sm rounded-cta bg-surface p-3.5 flex flex-col gap-2" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :variants,
        description:
          "The placeholder matches the height of the real item, so content landing does not " <>
            "shift the layout. The shimmer stops under prefers-reduced-motion.",
        variations: [
          %Variation{id: :card, attributes: %{variant: "card"}},
          %Variation{id: :rows, attributes: %{variant: "row", count: 4}}
        ]
      },
      %Variation{
        id: :card_list,
        description:
          "Several cards, each with a staggered delay so the page does not pulse as one.",
        attributes: %{variant: "card", count: 3}
      }
    ]
  end
end

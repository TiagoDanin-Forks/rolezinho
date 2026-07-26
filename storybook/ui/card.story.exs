defmodule Storybook.UI.Card do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.Card.card/1

  def template do
    """
    <div class="max-w-sm flex flex-col gap-2" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :radii,
        description:
          "A white surface on the cream canvas with a hairline border and no resting shadow — " <>
            "the canvas contrast is what gives it shape.",
        variations: [
          %Variation{id: :box, slots: ["Default card, 1.125rem corner."]},
          %Variation{
            id: :panel,
            attributes: %{radius: "panel", padding: "lg"},
            slots: ["Panel, 1.5rem corner and roomier padding."]
          },
          %Variation{
            id: :field,
            attributes: %{radius: "field", padding: "sm"},
            slots: ["Compact, for a nested block."]
          }
        ]
      }
    ]
  end
end

defmodule Storybook.UI.Well do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.Card.well/1

  def template do
    """
    <div class="max-w-sm rounded-card border border-ink/8 bg-white p-4" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :well,
        description:
          "The recessed area inside a card, used to frame a grouped zone. Shown here inside a " <>
            "real card, which is the only place it belongs.",
        variations: [
          %Variation{id: :text, slots: ["Anything framed inside a card."]}
        ]
      }
    ]
  end
end

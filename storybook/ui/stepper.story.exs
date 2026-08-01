defmodule Storybook.UI.Stepper do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.Stepper.stepper/1

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
        id: :bounds,
        description:
          "Preferred over a number input on a phone: no keyboard, changed with the thumb. " <>
            "The buttons disable at the bounds instead of silently clamping.",
        variations: [
          %Variation{
            id: :middle,
            attributes: %{
              label: "How many people?",
              hint: "You plus guests",
              value: 2,
              dec: "dec",
              inc: "inc"
            }
          },
          %Variation{
            id: :at_min,
            attributes: %{label: "How many people?", value: 1, dec: "dec", inc: "inc"}
          },
          %Variation{
            id: :at_max,
            attributes: %{label: "How many people?", value: 9, dec: "dec", inc: "inc"}
          },
          %Variation{
            id: :capacity,
            attributes: %{
              label: "Slots",
              hint: "Main list",
              value: 18,
              min: 1,
              max: 60,
              dec: "dec",
              inc: "inc"
            }
          }
        ]
      }
    ]
  end
end

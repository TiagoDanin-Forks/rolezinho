defmodule Storybook.UI.SectionHeader do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.SectionHeader.section_header/1

  def template do
    """
    <div class="max-w-sm rounded-cta bg-surface p-3.5 flex flex-col gap-3.5" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :sections,
        description:
          "Separates the main list from the waitlist. The counter is a badge because it is " <>
            "scanned, not read.",
        variations: [
          %Variation{
            id: :main,
            attributes: %{title: "Main list", count: 17, capacity: 18}
          },
          %Variation{
            id: :waitlist,
            attributes: %{title: "Waitlist", count: 3, tone: "muted"}
          },
          %Variation{id: :no_count, attributes: %{title: "Payment"}}
        ]
      }
    ]
  end
end

defmodule Storybook.UI.DetailRow do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.InfoTile.detail_row/1

  def template do
    """
    <div class="max-w-sm rounded-cta bg-surface p-3.5" psb-code-hidden>
      <div class="rounded-cta border border-ink/8 bg-white px-3.5">
        <.psb-variation-group/>
      </div>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :invite_details,
        description:
          "The labeled lines of an invite, stacked inside one bordered container. " <>
            "Pass divider={false} on the last one.",
        variations: [
          %Variation{id: :where, attributes: %{label: "Where", value: "Rua Caripunas"}},
          %Variation{
            id: :when,
            attributes: %{label: "When", value: "Wednesday, 7pm", divider: false}
          }
        ]
      }
    ]
  end
end

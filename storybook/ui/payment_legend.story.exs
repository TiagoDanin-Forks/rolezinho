defmodule Storybook.UI.PaymentLegend do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.ProgressBar.payment_legend/1

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
        id: :legend,
        description:
          "Mandatory above the first list on any screen showing the check: a check on its own " <>
            "does not say whether it means paid or confirmed.",
        variations: [
          %Variation{id: :default, attributes: %{}},
          %Variation{
            id: :custom_labels,
            attributes: %{paid_label: "settled up", unpaid_label: "still owes"}
          }
        ]
      }
    ]
  end
end

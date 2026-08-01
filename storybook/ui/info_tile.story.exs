defmodule Storybook.UI.InfoTile do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.InfoTile.info_tile/1

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
        id: :values,
        description:
          "The amount and the Pix key: an overline label, the value in weight 800, and an " <>
            "optional inline action.",
        variations: [
          %Variation{id: :amount, attributes: %{label: "Amount", value: "R$ 15"}},
          %Variation{
            id: :pix_key,
            attributes: %{label: "Pix key", value: "91984933238", action: "Copy"}
          },
          %Variation{id: :large, attributes: %{label: "Amount", value: "R$ 15", size: "lg"}}
        ]
      },
      %Variation{
        id: :long_value,
        description:
          "A long value never wraps: it ellipsizes, so the block keeps its height and the " <>
            "action stays reachable.",
        attributes: %{
          label: "Pix key",
          value: "chave-aleatoria-muito-longa-8f3d9c2b-4a1e-4d5f-9c7b-2e8a1f6d3b0c",
          action: "Copy"
        }
      }
    ]
  end
end

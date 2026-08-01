defmodule Storybook.UI.FieldConfigRow do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.FieldConfigRow.field_config_row/1

  def template do
    """
    <div class="rounded-cta bg-surface p-3.5 flex flex-col gap-2 max-w-[358px]" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :states,
        description:
          "Name is locked: it identifies the person in the list, so removing it would leave " <>
            "rows with nothing to show.",
        variations: [
          %Variation{
            id: :locked_required,
            attributes: %{label: "Name", type: "text", required: true, locked: true}
          },
          %Variation{
            id: :required,
            attributes: %{label: "Number (WhatsApp)", type: "tel", required: true, value: "phone"}
          },
          %Variation{
            id: :optional,
            attributes: %{label: "Shirt (S/M/L)", type: "text", value: "shirt"}
          }
        ]
      }
    ]
  end
end

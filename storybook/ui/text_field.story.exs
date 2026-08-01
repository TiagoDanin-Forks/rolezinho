defmodule Storybook.UI.TextField do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.TextField.text_field/1

  def template do
    """
    <div class="max-w-sm rounded-cta bg-surface p-3.5 flex flex-col gap-3" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :fields,
        description:
          "The label sits above the field and there is no decorative placeholder — a " <>
            "placeholder that repeats the label vanishes exactly when it is still needed.",
        variations: [
          %Variation{
            id: :name,
            attributes: %{label: "Name", name: "name", value: "Tiago Danin", required: true}
          },
          %Variation{
            id: :phone,
            attributes: %{label: "Phone", name: "phone", type: "tel", value: ""}
          },
          %Variation{
            id: :error,
            attributes: %{
              label: "Name",
              name: "name_error",
              value: "",
              required: true,
              error: "Type the name that goes on the list."
            }
          }
        ]
      }
    ]
  end
end

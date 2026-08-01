defmodule Storybook.UI.SegmentedControl do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.SegmentedControl.segmented_control/1

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
        id: :selection,
        description:
          "Up to three short options. Past three the labels stop fitting on a phone — use a " <>
            "select instead.",
        variations: [
          %Variation{
            id: :text_selected,
            attributes: %{
              name: "field_type",
              value: "text",
              options: [{"text", "Text"}, {"tel", "Phone"}, {"number", "Number"}],
              change: "set_type"
            }
          },
          %Variation{
            id: :phone_selected,
            attributes: %{
              name: "field_type_2",
              value: "tel",
              options: [{"text", "Text"}, {"tel", "Phone"}, {"number", "Number"}],
              change: "set_type"
            }
          },
          %Variation{
            id: :two_options,
            attributes: %{
              name: "period",
              value: "upcoming",
              options: [{"upcoming", "Upcoming"}, {"past", "Past"}],
              change: "set_period"
            }
          }
        ]
      }
    ]
  end
end

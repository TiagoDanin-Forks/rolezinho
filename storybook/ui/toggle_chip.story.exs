defmodule Storybook.UI.ToggleChip do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.ToggleChip.toggle_chip/1

  def template do
    """
    <div class="max-w-sm rounded-cta bg-surface p-3.5 flex gap-2" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :on_off,
        description:
          "On is orange with white text — the same active-state role orange has elsewhere.",
        variations: [
          %Variation{
            id: :on,
            attributes: %{
              on: true,
              click: "toggle_required",
              label_on: "Required",
              label_off: "Optional",
              uppercase: true
            }
          },
          %Variation{
            id: :off,
            attributes: %{
              on: false,
              click: "toggle_required",
              label_on: "Required",
              label_off: "Optional",
              uppercase: true
            }
          }
        ]
      },
      %VariationGroup{
        id: :share_toggles,
        description:
          "The share sheet's toggles, where the label does not change with the state — only " <>
            "the color says whether it is on.",
        variations: [
          %Variation{
            id: :include_link,
            attributes: %{on: true, click: "toggle_link", label_on: "Include link"}
          },
          %Variation{
            id: :include_password,
            attributes: %{on: false, click: "toggle_pass", label_on: "Include password"}
          }
        ]
      }
    ]
  end
end

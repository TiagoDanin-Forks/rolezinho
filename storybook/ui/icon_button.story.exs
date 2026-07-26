defmodule Storybook.UI.IconButton do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.IconButton.icon_button/1

  def template do
    """
    <div class="rounded-cta bg-surface p-3.5 flex items-center gap-2.5" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :tones,
        description:
          "soft is the default, on the page's own surface; ink is for a header over an image. " <>
            "label is required and becomes the aria-label.",
        variations: [
          %Variation{id: :back, attributes: %{name: "tabler-arrow-left", label: "Back"}},
          %Variation{id: :share, attributes: %{name: "tabler-share", label: "Share"}},
          %Variation{id: :edit, attributes: %{name: "tabler-pencil", label: "Edit"}},
          %Variation{
            id: :ink,
            attributes: %{name: "tabler-dots", label: "More options", tone: "ink"}
          }
        ]
      }
    ]
  end
end

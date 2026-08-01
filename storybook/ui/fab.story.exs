defmodule Storybook.UI.Fab do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.IconButton.fab/1

  def template do
    """
    <div class="max-w-sm rounded-cta bg-surface p-3.5 flex justify-end" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :fab,
        description:
          "The floating action button that creates an event. 44px target and a raised shadow, " <>
            "bottom right, within thumb reach.",
        variations: [
          %Variation{id: :create, attributes: %{label: "Create event"}},
          %Variation{
            id: :custom_icon,
            attributes: %{label: "Share", name: "tabler-share"}
          }
        ]
      }
    ]
  end
end

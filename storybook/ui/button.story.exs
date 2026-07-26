defmodule Storybook.UI.Button do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.Button.action_button/1

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
        id: :variants,
        description:
          "One primary per screen, at the bottom. outline is the escape hatch next to it; " <>
            "ghost is the quiet dismissal.",
        variations: [
          %Variation{id: :primary, slots: ["Join the list"]},
          %Variation{
            id: :outline,
            attributes: %{variant: "outline"},
            slots: ["Just look at the list"]
          },
          %Variation{id: :ghost, attributes: %{variant: "ghost"}, slots: ["Not now"]},
          %Variation{id: :danger, attributes: %{variant: "danger"}, slots: ["Remove"]}
        ]
      },
      %VariationGroup{
        id: :states,
        description:
          "disabled drops to 40% and blocks the tap. loading also blocks it and marks aria-busy.",
        variations: [
          %Variation{id: :disabled, attributes: %{disabled: true}, slots: ["Create event"]},
          %Variation{id: :loading, attributes: %{loading: true}, slots: ["Joining"]}
        ]
      },
      %Variation{
        id: :inline,
        description: "full_width={false} renders an inline button, for an empty state's CTA.",
        attributes: %{full_width: false},
        slots: ["Create event"]
      },
      %Variation{
        id: :as_a_link,
        description: "href/navigate/patch render an anchor with the same styling.",
        attributes: %{navigate: "/", variant: "outline"},
        slots: ["Back to the home page"]
      }
    ]
  end
end

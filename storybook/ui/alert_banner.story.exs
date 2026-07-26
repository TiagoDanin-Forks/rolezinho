defmodule Storybook.UI.AlertBanner do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.AlertBanner.alert_banner/1

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
        id: :tones,
        description:
          "A banner states a condition that is still true. A toast confirms something that " <>
            "just happened and leaves — do not swap one for the other.",
        variations: [
          %Variation{
            id: :info,
            attributes: %{tone: "info"},
            slots: ["3 people have not paid yet."]
          },
          %Variation{
            id: :info_with_action,
            attributes: %{tone: "info", action: "Charge", action_click: "remind"},
            slots: ["3 people have not paid yet."]
          },
          %Variation{
            id: :warn,
            attributes: %{tone: "warn"},
            slots: ["You are on the waitlist. A slot opens if someone leaves."]
          },
          %Variation{
            id: :danger,
            attributes: %{tone: "danger", action: "Retry", action_click: "retry"},
            slots: ["Could not save. Check your connection."]
          }
        ]
      }
    ]
  end
end

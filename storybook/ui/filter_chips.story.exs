defmodule Storybook.UI.FilterChips do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.FilterChips.filter_chips/1

  def template do
    """
    <div class="rounded-cta bg-surface p-3.5" psb-code-hidden>
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :default,
        description:
          "Scrolls sideways rather than wrapping: a second line would push the listing down.",
        attributes: %{value: "all"},
        slots: [
          ~s(<:chip id="all" label="All" />),
          ~s(<:chip id="sport" label="Sport" />),
          ~s(<:chip id="cowork" label="Coworking" />),
          ~s(<:chip id="social" label="Social" />)
        ]
      },
      %Variation{
        id: :selected,
        description: "Selection lives in aria-checked, not in a conditional class.",
        attributes: %{value: "sport"},
        slots: [
          ~s(<:chip id="all" label="All" />),
          ~s(<:chip id="sport" label="Sport" />),
          ~s(<:chip id="cowork" label="Coworking" />)
        ]
      }
    ]
  end
end

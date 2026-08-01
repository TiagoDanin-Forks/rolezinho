defmodule Storybook.UI.DateTimeField do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.DateTimeField.date_time_field/1

  def template do
    """
    <div class="rounded-cta bg-surface p-3.5 max-w-[358px]" psb-code-hidden>
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :filled,
        description:
          "Native inputs so the phone opens its own picker. Real values are what let the " <>
            "listing sort and the .ics carry a correct timestamp.",
        attributes: %{date: "2026-07-15", starts_at: "19:00", ends_at: "21:00"}
      },
      %Variation{
        id: :empty,
        description: "Creating an event, before anything is chosen.",
        attributes: %{}
      }
    ]
  end
end

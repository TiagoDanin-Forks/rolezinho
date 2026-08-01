defmodule Storybook.UI.Coachmark do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.Coachmark.coachmark/1

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
        id: :paid_check,
        description:
          "Shown once per device: dismissal is remembered in localStorage. At most one per " <>
            "screen and three in the whole app — a hint that always appears stops being read. " <>
            "It starts hidden and the hook reveals it, so someone who dismissed it long ago " <>
            "never sees a flash of it.",
        attributes: %{seen_key: "paid-check-demo"},
        slots: ["Tap here once you have paid. Only you can mark your own."]
      }
    ]
  end
end

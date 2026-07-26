defmodule Storybook.UI.SwipeActions do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.SwipeActions.swipe_actions/1

  def template do
    """
    <div class="rounded-cta bg-surface p-3.5 max-w-[358px]" psb-code-hidden>
      <.psb-variation/>
      <p class="mt-2 text-[10.5px] text-ink/45">Drag the row to the left.</p>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :admin_row,
        description:
          "An accelerator for an organizer going through eighteen rows, never the only way " <>
            "in: the same actions stay reachable as buttons, and the destructive one sits " <>
            "furthest out so an overshoot lands on the safe action. Removal still confirms.",
        attributes: %{value: "4"},
        slots: [
          ~s(<:action label="Paid" tone="accent" />),
          ~s(<:action label="Remove" tone="danger" />),
          """
          <div class="flex items-center gap-2.5 px-3.5 py-3">
            <span class="w-4 text-[11px] font-bold text-ink/30">4</span>
            <span class="flex-1 text-[13px] font-semibold">Henrique</span>
          </div>
          """
        ]
      }
    ]
  end
end

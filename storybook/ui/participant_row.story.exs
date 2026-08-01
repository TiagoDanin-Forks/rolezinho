defmodule Storybook.UI.ParticipantRow do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.ParticipantRow.participant_row/1

  def template do
    """
    <div class="max-w-sm rounded-cta bg-surface p-3.5" psb-code-hidden>
      <div class="overflow-hidden rounded-cta border border-ink/8 bg-white">
        <.psb-variation-group/>
      </div>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :states,
        description:
          "The four states of a line. A slot keeps its number even when empty — freeing one " <>
            "never renumbers the others.",
        variations: [
          %Variation{id: :paid, attributes: %{number: 1, name: "Marcia", paid: true}},
          %Variation{id: :unpaid, attributes: %{number: 2, name: "Robertinha"}},
          %Variation{
            id: :highlighted,
            attributes: %{number: 3, name: "Tiago", paid: true, highlighted: true}
          },
          %Variation{
            id: :empty,
            attributes: %{number: 4, join_click: "join", divider: false}
          }
        ]
      },
      %VariationGroup{
        id: :interactive_check,
        description:
          "With paid_click the check becomes a button and announces aria-pressed. Without it " <>
            "the check is read-only. The permission is re-checked in the handler — a hidden " <>
            "button is not a gate.",
        variations: [
          %Variation{
            id: :clickable,
            attributes: %{number: 1, name: "Henrique", paid_click: "toggle_paid"}
          },
          %Variation{
            id: :read_only,
            attributes: %{number: 2, name: "Rivanete", paid: true, divider: false}
          }
        ]
      },
      %VariationGroup{
        id: :with_admin_actions,
        description: "The actions slot carries the admin controls: promote, remove.",
        variations: [
          %Variation{
            id: :removable,
            attributes: %{number: 1, name: "Marcia", paid: true},
            slots: [
              """
              <:actions>
                <button class="text-[13px] text-ink/35" aria-label="Remove Marcia">x</button>
              </:actions>
              """
            ]
          },
          %Variation{
            id: :promotable,
            attributes: %{number: 2, name: "Rivanete", divider: false},
            slots: [
              """
              <:actions>
                <button class="text-[11px] font-bold text-accent">Promote</button>
              </:actions>
              """
            ]
          }
        ]
      }
    ]
  end
end

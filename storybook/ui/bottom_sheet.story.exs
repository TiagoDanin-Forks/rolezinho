defmodule Storybook.UI.BottomSheet do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.BottomSheet.bottom_sheet/1

  # The sheet's actions are real buttons, not hand-written markup: a story that
  # rebuilds a button out of loose classes drifts from the component it sits next
  # to in the catalog.
  def imports, do: [{RolezinhoWeb.Components.UI.Button, action_button: 1}]

  def variations do
    [
      %Variation{
        id: :remove,
        description:
          "The destructive confirmation. The destructive action always sits on the right, in " <>
            "the danger tone. Rendered open here; in the app it is opened with " <>
            "BottomSheet.show/1, a JS command rather than a hook, so the state survives a " <>
            "re-render from the server.",
        attributes: %{
          id: "sheet-remove",
          title: "Remove from the list?",
          description: "Someone on the waitlist can be promoted into the slot.",
          open: true
        },
        slots: [
          """
          <:actions>
            <.action_button variant="outline" class="flex-1">Cancel</.action_button>
            <.action_button variant="danger" class="flex-1">Remove</.action_button>
          </:actions>
          """
        ]
      },
      %Variation{
        id: :join,
        description: "The join sheet, carrying the fields the organizer configured.",
        attributes: %{id: "sheet-join", title: "Join the list", open: true},
        slots: [
          """
          <div class="rounded-row border border-ink/15 px-3.5 py-3 text-[13px] font-semibold">
            Tiago Danin
          </div>
          """,
          """
          <:actions>
            <.action_button class="flex-1">Confirm</.action_button>
          </:actions>
          """
        ]
      }
    ]
  end
end

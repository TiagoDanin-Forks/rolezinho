defmodule Storybook.UI.EmptyState do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.EmptyState.empty_state/1

  def template do
    """
    <div class="max-w-sm" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :with_cta,
        description: "An empty state always offers exactly one way out.",
        attributes: %{
          icon: "tabler-calendar-plus",
          title: "No events around here",
          body: "Create the first one and drop the link in the group."
        },
        slots: [
          """
          <:cta>
            <span class="inline-flex rounded-card bg-ink px-4 py-3 text-xs font-bold text-ink-content">
              Create event
            </span>
          </:cta>
          """
        ]
      },
      %Variation{
        id: :no_results,
        description:
          "A filter with no match needs no CTA — the way out is changing the filter, which " <>
            "is already on screen.",
        attributes: %{
          icon: "tabler-search",
          title: "Nothing here",
          body: "No event matches this filter."
        }
      },
      %Variation{
        id: :title_only,
        description: "The body is optional when the title already says everything.",
        attributes: %{title: "Empty waitlist"}
      }
    ]
  end
end

defmodule Storybook.UI.SearchField do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.SearchField.search_field/1

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
        id: :empty,
        description: "Filters without reordering — a slot keeps the number it has in the list.",
        attributes: %{placeholder: "Find a name in the list"}
      },
      %Variation{
        id: :filled,
        description: "The clear button appears once there is something to clear.",
        attributes: %{
          value: "Marcia",
          placeholder: "Find a name in the list",
          on_clear: "clear"
        }
      }
    ]
  end
end

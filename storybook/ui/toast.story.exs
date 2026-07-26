defmodule Storybook.UI.Toast do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.Toast.toast/1

  def template do
    """
    <div class="relative h-28 max-w-sm overflow-hidden rounded-cta bg-surface" psb-code-hidden>
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :copied,
        description:
          "Short, no action, leaves on its own. In the app it is fixed to the bottom of the " <>
            "viewport; here it is contained so it can be seen.",
        attributes: %{message: "Pix key copied!", class: "absolute"}
      },
      %Variation{
        id: :saved,
        description: "The confirmation after an entry is saved.",
        attributes: %{message: "You are on the list", class: "absolute"}
      }
    ]
  end
end

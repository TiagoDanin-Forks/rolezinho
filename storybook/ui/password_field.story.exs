defmodule Storybook.UI.PasswordField do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.TextField.password_field/1

  def template do
    """
    <div class="max-w-sm rounded-cta bg-surface p-3.5 flex flex-col gap-4" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :password,
        description:
          "Large and letter-spaced: it is transcribed from a chat message, often wrong the " <>
            "first time. The error says what to do, not only what failed.",
        variations: [
          %Variation{id: :empty, attributes: %{name: "password_empty", value: ""}},
          %Variation{id: :filled, attributes: %{name: "password_ok", value: "VOLEI25"}},
          %Variation{
            id: :wrong,
            attributes: %{
              name: "password_err",
              value: "VOLEI24",
              error: "Wrong password. Check with whoever invited you."
            }
          }
        ]
      }
    ]
  end
end

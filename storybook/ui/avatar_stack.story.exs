defmodule Storybook.UI.AvatarStack do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.Avatar.avatar_stack/1

  def template do
    """
    <div class="max-w-sm rounded-cta bg-surface p-3.5 flex flex-col gap-3.5" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :stacks,
        description:
          "Who is already in, shown before the CTA. Past max it collapses into +N. " <>
            "ring_class must match the surface behind the stack — here base-200.",
        variations: [
          %Variation{
            id: :overflowing,
            attributes: %{
              names: ~w(Marcia Robertinha Henrique Rivanete Gisele Elisa Bruno Ana Carla),
              max: 5,
              ring_class: "ring-surface"
            }
          },
          %Variation{
            id: :under_max,
            attributes: %{names: ~w(Marcia Robertinha Henrique), ring_class: "ring-surface"}
          },
          %Variation{
            id: :small,
            attributes: %{
              names: ~w(Ana Bruno Carla Diego),
              size: "xs",
              max: 4,
              ring_class: "ring-surface"
            }
          }
        ]
      }
    ]
  end
end

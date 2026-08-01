defmodule Storybook.UI.Avatar do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.Avatar.avatar/1

  def template do
    """
    <div class="rounded-cta bg-surface p-3.5 flex items-center gap-2.5" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %VariationGroup{
        id: :sizes,
        description: "The initial over a color derived from the name. Nothing is uploaded.",
        variations: [
          %Variation{id: :xs, attributes: %{name: "Marcia", size: "xs"}},
          %Variation{id: :sm, attributes: %{name: "Henrique", size: "sm"}},
          %Variation{id: :md, attributes: %{name: "Rivanete", size: "md"}},
          %Variation{id: :lg, attributes: %{name: "Tiago", size: "lg"}}
        ]
      },
      %VariationGroup{
        id: :colors,
        description:
          "The hue comes from a hash of the name, so the same person keeps the same color " <>
            "across screens with nothing stored.",
        variations:
          for name <- ~w(Ana Bruno Carla Diego Elisa Fabio Gisele) do
            %Variation{id: String.to_atom(String.downcase(name)), attributes: %{name: name}}
          end
      }
    ]
  end
end

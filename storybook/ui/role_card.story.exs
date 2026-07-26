defmodule Storybook.UI.RoleCard do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.RoleCard.role_card/1

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
        id: :open,
        description: "The bar repeats the counter visually — it reads faster than 17/18.",
        attributes: %{
          title: "Beach volleyball",
          when_text: "Wednesday · 7pm to 9pm",
          category: "Sport",
          status: "open",
          filled: 17,
          capacity: 18,
          names: ["Marcia", "Roberta", "Henrique", "Yngrid"],
          navigate: "/"
        }
      },
      %Variation{
        id: :full,
        description: "A full list keeps the link: someone may still leave.",
        attributes: %{
          title: "Beach volleyball",
          when_text: "Wednesday · 7pm to 9pm",
          category: "Sport",
          status: "full",
          filled: 18,
          capacity: 18,
          names: ["Marcia", "Roberta", "Henrique"],
          navigate: "/"
        }
      },
      %Variation{
        id: :minimal,
        description: "Without a category or a list yet — right after it is created.",
        attributes: %{
          title: "Friday barbecue",
          when_text: "Friday · 6pm",
          navigate: "/"
        }
      }
    ]
  end
end

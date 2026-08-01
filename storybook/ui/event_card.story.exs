defmodule Storybook.UI.EventCard do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.EventCard.event_card/1

  def template do
    """
    <div class="max-w-sm rounded-cta bg-surface p-3.5 flex flex-col gap-2" psb-code-hidden>
      <.psb-variation-group/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :filling,
        description:
          "The whole card is the link: on a phone a small 'see more' target is a miss " <>
            "waiting to happen.",
        attributes: %{
          title: "Volleyball at the beach",
          subtitle: "Wednesday, 7pm to 9pm",
          names: ~w(Marcia Robertinha Henrique Rivanete Gisele),
          filled: 17,
          capacity: 18,
          navigate: "/"
        }
      },
      %Variation{
        id: :with_badge,
        description: "The badge slot carries a status pill above the title.",
        attributes: %{
          title: "Coworking downtown",
          subtitle: "Every Tuesday, 9am",
          names: ~w(Ana Bruno),
          filled: 2,
          capacity: 10,
          navigate: "/"
        },
        slots: [
          """
          <:badge>
            <span class="rounded-row bg-tint px-3 py-[7px] text-[11px] font-bold text-ink-ink">
              Slots open
            </span>
          </:badge>
          """
        ]
      },
      %Variation{
        id: :empty,
        description: "With nobody in yet, the stack gives way to explicit text.",
        attributes: %{
          title: "Sunday barbecue",
          subtitle: "Sunday, noon",
          filled: 0,
          capacity: 12,
          navigate: "/"
        }
      },
      %Variation{
        id: :no_capacity,
        description: "With no defined capacity there is no bar — an unbounded list.",
        attributes: %{
          title: "Open list",
          subtitle: "Saturday",
          names: ~w(Carla Diego Elisa),
          filled: 3,
          navigate: "/"
        }
      }
    ]
  end
end

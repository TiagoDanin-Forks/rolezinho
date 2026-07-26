defmodule Storybook.UI.InviteCard do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.InviteCard.invite_card/1

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
        description: "Inverted against the listing: it is the one card with a deadline.",
        attributes: %{
          title: "You were invited to Beach volleyball",
          navigate: "/"
        }
      },
      %Variation{
        id: :locked,
        description:
          "The lock announces the password before the tap, so the ask is not a surprise.",
        attributes: %{
          title: "You were invited to Beach volleyball",
          locked: true,
          navigate: "/"
        }
      }
    ]
  end
end

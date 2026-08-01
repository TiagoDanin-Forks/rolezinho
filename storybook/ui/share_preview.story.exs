defmodule Storybook.UI.SharePreview do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.SharePreview.share_preview/1

  def template do
    """
    <div class="max-w-sm rounded-cta bg-surface p-3.5" psb-code-hidden>
      <.psb-variation/>
    </div>
    """
  end

  def variations do
    [
      %Variation{
        id: :event_text,
        description:
          "What gets pasted into the group, character for character. A preview that " <>
            "prettifies the text lies about what lands in the chat.",
        attributes: %{
          text: """
          # VOLLEYBALL AT THE BEACH

          Where: Rua Caripunas
          Wednesday (07/15)
          Time: 7pm to 9pm
          Amount: R$ 15
          Pix: 91984933238

          1- Marcia (paid)
          2- Robertinha
          3- Henrique (paid)

          Waitlist
          1- Rivanete

          *PAYMENT BY PIX ONLY*

          Join the list: rolezinho.app/r/volleyball
          List password: VOLEI25\
          """
        }
      }
    ]
  end
end

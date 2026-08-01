defmodule RolezinhoWeb.Components.UI.InviteCard do
  @moduledoc """
  A pending invite, at the top of the home screen.

  Inverted against the rest of the listing — ink fill where the other cards are
  light — because it is the one thing on the screen with a deadline. The lock
  says upfront that a password will be asked for, so the ask does not arrive as
  a surprise after the tap.
  """
  use Phoenix.Component

  import RolezinhoWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders the invite card.

  ## Examples

      <.invite_card title="You were invited to Beach volleyball" navigate={~p"/r/volei"} />
      <.invite_card title="You were invited" locked navigate={~p"/r/volei"} />
  """
  attr :title, :string, required: true
  attr :overline, :string, default: "Invite received"
  attr :locked, :boolean, default: false
  attr :locked_hint, :string, default: "Asks for a password to join"
  attr :navigate, :string, default: nil
  attr :class, :any, default: nil

  def invite_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-3 rounded-card bg-ink p-4",
        "transition-transform active:scale-[.99]",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        @class
      ]}
    >
      <div class="min-w-0 flex-1">
        <div class="flex items-center gap-1.5">
          <span class="text-[10px] font-bold uppercase tracking-wide text-accent">{@overline}</span>
          <.icon :if={@locked} name="tabler-lock" class="size-3 text-ink-content/50" />
        </div>
        <div class="mt-1 text-sm font-bold text-ink-content">{@title}</div>
        <div :if={@locked} class="mt-0.5 text-[10.5px] text-ink-content/50">{@locked_hint}</div>
      </div>
      <.icon name="tabler-arrow-right" class="size-5 shrink-0 text-ink-content/50" />
    </.link>
    """
  end
end

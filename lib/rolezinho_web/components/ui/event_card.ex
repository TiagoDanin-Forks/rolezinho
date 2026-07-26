defmodule RolezinhoWeb.Components.UI.EventCard do
  @moduledoc """
  An event as it appears on the home listing.

  The card answers, in the order the reader asks: which event, when, who is
  already in, and how full it is. The whole card is the link — on a phone, a
  small "see more" target is a miss waiting to happen.
  """
  use Phoenix.Component

  import RolezinhoWeb.Components.UI.Avatar, only: [avatar_stack: 1]
  import RolezinhoWeb.Components.UI.ProgressBar, only: [progress_bar: 1]

  @doc """
  Renders the event card.

  ## Examples

      <.event_card
        title="Volleyball at the beach"
        navigate={~p"/r/volei"}
        subtitle="Wednesday, 7pm to 9pm"
        names={["Marcia", "Robertinha"]}
        filled={17}
        capacity={18}
      />
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :names, :list, default: [], doc: "confirmed names, for the avatar stack"
  attr :filled, :integer, default: 0
  attr :capacity, :integer, default: 0
  attr :locked, :boolean, default: false, doc: "the event asks for a password"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch)

  slot :badge, doc: "a status pill or category marker above the title"

  def event_card(assigns) do
    ~H"""
    <.link
      class={[
        "block rounded-card border border-ink/8 bg-white p-3.5 transition",
        "hover:border-ink/15 active:scale-[0.99] motion-reduce:active:scale-100",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        @class
      ]}
      {@rest}
    >
      <div :if={@badge != []} class="mb-2 flex items-center gap-2">{render_slot(@badge)}</div>

      <h3 class="text-lg font-extrabold tracking-tight">{@title}</h3>
      <p :if={@subtitle} class="mt-0.5 text-xs text-muted">{@subtitle}</p>

      <div class="mt-3 flex items-center justify-between gap-3">
        <.avatar_stack :if={@names != []} names={@names} size="xs" max={4} />
        <span :if={@names == []} class="text-[11px] font-semibold text-muted">
          Nobody in yet
        </span>
        <span class="shrink-0 text-[11px] font-semibold text-muted">
          {@filled}/{@capacity} confirmed
        </span>
      </div>

      <.progress_bar :if={@capacity > 0} filled={@filled} capacity={@capacity} class="mt-2.5" />
    </.link>
    """
  end
end

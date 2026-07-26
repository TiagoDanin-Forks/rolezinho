defmodule RolezinhoWeb.Components.UI.EmptyState do
  @moduledoc """
  Nothing here yet — first visit, empty history, a filter with no match.

  An empty state always offers exactly one way out. It is not used for network
  errors: those need a retry, which is `alert_banner/1`.
  """
  use Phoenix.Component

  import RolezinhoWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders the empty state.

  ## Examples

      <.empty_state
        icon="tabler-calendar-plus"
        title="No events around here"
        body="Create the first one and drop the link in the group."
      >
        <:cta>
          <.action_button navigate={~p"/admin/new"} full_width={false}>
            Create event
          </.action_button>
        </:cta>
      </.empty_state>
  """
  attr :icon, :string, default: "tabler-inbox"
  attr :title, :string, required: true
  attr :body, :string, default: nil
  attr :class, :any, default: nil

  slot :cta, doc: "the single way out of the empty state"

  def empty_state(assigns) do
    ~H"""
    <div class={["rounded-cta bg-surface px-3.5 py-6 text-center", @class]}>
      <span class="mx-auto inline-flex size-13 items-center justify-center rounded-card border border-ink/8 bg-white">
        <.icon name={@icon} class="size-6 text-ink/55" />
      </span>
      <h2 class="mt-3 text-[15px] font-extrabold">{@title}</h2>
      <p :if={@body} class="mx-auto mt-1.5 max-w-xs text-xs leading-relaxed text-ink/55">
        {@body}
      </p>
      <div :if={@cta != []} class="mt-3.5 flex justify-center">{render_slot(@cta)}</div>
    </div>
    """
  end
end

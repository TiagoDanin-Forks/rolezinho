defmodule RolezinhoWeb.Components.UI.RoleCard do
  @moduledoc """
  An event as it appears in the home listing.

  Carries the four things that decide whether someone taps: what it is, when it
  happens, who is already in, and whether there is still room. The occupancy bar
  repeats the counter visually — on a phone, in the sun, the bar reads faster
  than "17/18".
  """
  use Phoenix.Component

  import RolezinhoWeb.Components.UI.Avatar, only: [avatar_stack: 1]
  import RolezinhoWeb.Components.UI.ProgressBar, only: [progress_bar: 1]
  import RolezinhoWeb.Components.UI.StatusPill, only: [status_pill: 1]

  @doc """
  Renders the card.

  ## Examples

      <.role_card
        title="Beach volleyball"
        when_text="Wednesday · 7pm to 9pm"
        category="Sport"
        status="open"
        filled={17}
        capacity={18}
        names={["Marcia", "Roberta", "Henrique"]}
        navigate={~p"/r/beach-volleyball"}
      />
  """
  attr :title, :string, required: true
  attr :when_text, :string, default: nil
  attr :category, :string, default: nil
  attr :category_initial, :string, default: nil
  attr :status, :string, default: nil, values: ~w(open full done debt payments_only) ++ [nil]
  attr :status_label, :string, default: nil
  attr :filled, :integer, default: nil
  attr :capacity, :integer, default: nil
  attr :names, :list, default: []
  attr :navigate, :string, default: nil
  attr :class, :any, default: nil

  def role_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "block rounded-card border border-hairline bg-base-100 p-4 shadow-card",
        "transition-transform active:scale-[.99]",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
        @class
      ]}
    >
      <div :if={@category || @status} class="flex items-center gap-2">
        <span
          :if={@category}
          class="grid size-6 shrink-0 place-items-center rounded-lg bg-accent text-[11px] font-bold text-accent-content"
          aria-hidden="true"
        >
          {@category_initial || String.first(@category)}
        </span>
        <span :if={@category} class="text-[10px] font-semibold uppercase tracking-wide text-ink/45">
          {@category}
        </span>
        <.status_pill :if={@status} tone={@status} class="ml-auto">
          {@status_label || default_status_label(@status)}
        </.status_pill>
      </div>

      <div class="mt-2 text-lg font-extrabold tracking-tight">{@title}</div>
      <div :if={@when_text} class="mt-0.5 text-xs text-ink/55">{@when_text}</div>

      <div :if={@names != [] || @filled} class="mt-3 flex items-center justify-between gap-3">
        <.avatar_stack :if={@names != []} names={@names} size="xs" max={4} ring_class="ring-base-100" />
        <span :if={@filled && @capacity} class="ml-auto text-[11px] font-semibold text-ink/50">
          {@filled}/{@capacity} confirmed
        </span>
      </div>

      <.progress_bar :if={@filled && @capacity} filled={@filled} capacity={@capacity} class="mt-2.5" />
    </.link>
    """
  end

  defp default_status_label("open"), do: "Slots open"
  defp default_status_label("full"), do: "List full"
  defp default_status_label("done"), do: "Closed"
  defp default_status_label("debt"), do: "Pix pending"
  defp default_status_label("payments_only"), do: "Payments only"
end

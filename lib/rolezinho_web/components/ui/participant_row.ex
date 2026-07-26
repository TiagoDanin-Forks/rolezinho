defmodule RolezinhoWeb.Components.UI.ParticipantRow do
  @moduledoc """
  A line in a list: the densest and most important component in the product.

  Four states, in the order a reader meets them:

    * **paid** — filled name, orange check.
    * **unpaid** — filled name, empty check.
    * **highlighted** — the line is visually marked (warm tint, orange border).
      Use it for the entry the visitor just added, which is the closest this
      product gets to "you": there is no signed-in user (see `SECURITY.md`).
    * **empty** — a free slot, with the inline action to take it.

  A row keeps its number even when empty: a slot is a fixed position, not a
  queue, so freeing one never renumbers the others.

  `paid_click` decides whether the check is interactive. Any privileged action
  must re-check permission in the handler — a hidden button is not a gate.
  """
  use Phoenix.Component

  import RolezinhoWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders one line of a list.

  ## Examples

      <.participant_row number={1} name="Marcia" paid />
      <.participant_row number={2} name="Robertinha" />
      <.participant_row number={3} name="Tiago" paid highlighted />
      <.participant_row number={4} empty_label="Free slot" join_label="Join" />
  """
  attr :number, :integer, required: true
  attr :name, :string, default: nil, doc: "nil or blank renders the empty state"
  attr :paid, :boolean, default: false
  attr :highlighted, :boolean, default: false, doc: "marks the row as the visitor's own entry"
  attr :divider, :boolean, default: true

  attr :paid_click, :any,
    default: nil,
    doc: "phx-click for the check; when nil the check is read-only"

  attr :join_click, :any, default: nil, doc: "phx-click for the empty slot action"
  attr :empty_label, :string, default: "Free slot"
  attr :join_label, :string, default: "Join"
  attr :class, :any, default: nil

  # The row's own buttons carry whatever identifies it to the caller's handlers
  # (typically phx-value-index): the component knows the position, the caller
  # knows what to do with it.
  attr :rest, :global, include: ~w(phx-value-index phx-value-id)

  slot :actions, doc: "trailing admin actions (remove, promote)"

  def participant_row(assigns) do
    assigns = assign(assigns, :empty?, blank?(assigns.name))

    ~H"""
    <div class={[
      "flex items-center gap-2.5 px-3.5 py-3",
      @divider && "border-b border-ink/6",
      @highlighted && "bg-tint",
      @class
    ]}>
      <span class="w-4 shrink-0 text-[11px] font-bold text-ink/30">{@number}</span>

      <span :if={@empty?} class="flex-1 text-[13px] font-semibold text-ink/30">
        {@empty_label}
      </span>
      <span :if={not @empty?} class={["flex-1 text-[13px]", name_classes(@highlighted)]}>
        {@name}
      </span>

      <button
        :if={@empty? && @join_click}
        type="button"
        phx-click={@join_click}
        class="shrink-0 cursor-pointer text-[11px] font-bold text-accent hover:underline"
        {@rest}
      >
        {@join_label}
      </button>

      <.check
        :if={not @empty?}
        paid={@paid}
        highlighted={@highlighted}
        click={@paid_click}
        rest={@rest}
      />

      {render_slot(@actions)}
    </div>
    """
  end

  attr :paid, :boolean, required: true
  attr :highlighted, :boolean, required: true
  attr :click, :any, required: true
  attr :rest, :map, default: %{}

  defp check(assigns) do
    ~H"""
    <button
      :if={@click}
      type="button"
      phx-click={@click}
      aria-pressed={to_string(@paid)}
      aria-label={if @paid, do: "Mark as unpaid", else: "Mark as paid"}
      class={[
        "-m-3 grid shrink-0 cursor-pointer place-items-center p-3",
        "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      ]}
      {@rest}
    >
      <span class={["transition", check_classes(@paid, @highlighted)]}>
        <.icon :if={@paid} name="tabler-check" class="size-3.5" />
      </span>
    </button>
    <span
      :if={!@click}
      role="img"
      aria-label={if @paid, do: "Paid", else: "Not paid yet"}
      class={["shrink-0", check_classes(@paid, @highlighted)]}
    >
      <.icon :if={@paid} name="tabler-check" class="size-3.5" />
    </span>
    """
  end

  defp check_classes(paid, highlighted) do
    [
      "inline-flex size-[22px] items-center justify-center rounded-full text-xs",
      paid && "border-[1.5px] border-accent bg-accent text-accent-content",
      not paid && "border-[1.5px]",
      not paid && if(highlighted, do: "border-accent", else: "border-ink/15")
    ]
  end

  defp name_classes(true), do: "font-bold"
  defp name_classes(false), do: "font-semibold"

  defp blank?(nil), do: true
  defp blank?(name), do: String.trim(name) == ""
end

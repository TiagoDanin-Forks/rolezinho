defmodule RolezinhoWeb.Components.UI.IconButton do
  @moduledoc """
  Round icon-only buttons: back, share, edit (`icon_button/1`) and the create
  action (`fab/1`).

  Both render at least a 44px touch target even when the visual circle is
  smaller, so the thumb has room (see `DESIGN.md`, section 4).
  """
  use Phoenix.Component

  import RolezinhoWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a round icon button.

  `label` is required and becomes the `aria-label`: an icon supports a label, it
  does not replace one.

  ## Examples

      <.icon_button name="tabler-arrow-left" label="Back" phx-click="back" />
      <.icon_button name="tabler-share" label="Share" tone="ink" />
  """
  attr :name, :string, required: true, doc: "a Tabler icon name"
  attr :label, :string, required: true, doc: "accessible name for the action"
  attr :tone, :string, default: "soft", values: ~w(soft ink)
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch method disabled)

  def icon_button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :anchor?, not is_nil(rest[:href] || rest[:navigate] || rest[:patch]))

    ~H"""
    <.link :if={@anchor?} class={[icon_classes(@tone), @class]} aria-label={@label} {@rest}>
      <.icon name={@name} class="size-[18px]" />
    </.link>
    <button
      :if={not @anchor?}
      type="button"
      class={[icon_classes(@tone), @class]}
      aria-label={@label}
      {@rest}
    >
      <.icon name={@name} class="size-[18px]" />
    </button>
    """
  end

  @doc """
  Renders the floating action button that creates an event.

  ## Examples

      <.fab label="Create event" navigate={~p"/criar"} />
  """
  attr :name, :string, default: "tabler-plus"
  attr :label, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch method disabled)

  def fab(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :anchor?, not is_nil(rest[:href] || rest[:navigate] || rest[:patch]))

    ~H"""
    <.link :if={@anchor?} class={[fab_classes(), @class]} aria-label={@label} {@rest}>
      <.icon name={@name} class="size-6" />
    </.link>
    <button
      :if={not @anchor?}
      type="button"
      class={[fab_classes(), @class]}
      aria-label={@label}
      {@rest}
    >
      <.icon name={@name} class="size-6" />
    </button>
    """
  end

  defp icon_classes(tone) do
    [
      "inline-flex size-11 items-center justify-center rounded-full transition",
      "active:scale-[0.97] motion-reduce:active:scale-100",
      "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent",
      tone == "soft" && "bg-ink/[0.06] text-ink hover:bg-ink/10",
      tone == "ink" && "bg-ink text-ink-content hover:opacity-90"
    ]
  end

  defp fab_classes do
    [
      "inline-flex size-11 items-center justify-center rounded-full transition",
      "bg-ink text-ink-content shadow-cta hover:opacity-90",
      "active:scale-[0.97] motion-reduce:active:scale-100",
      "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
    ]
  end
end

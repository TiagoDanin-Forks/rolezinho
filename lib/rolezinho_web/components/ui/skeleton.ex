defmodule RolezinhoWeb.Components.UI.Skeleton do
  @moduledoc """
  The loading placeholder for a list that comes from the server.

  A skeleton matches the height of the real item it stands in for, so content
  landing does not shift the layout. The shimmer is defined in `app.css` and
  stops under `prefers-reduced-motion`.
  """
  use Phoenix.Component

  @doc """
  Renders skeleton placeholders.

  ## Examples

      <.skeleton variant="card" />
      <.skeleton variant="row" count={4} />
  """
  attr :variant, :string, default: "row", values: ~w(card row)
  attr :count, :integer, default: 1
  attr :class, :any, default: nil

  def skeleton(assigns) do
    ~H"""
    <div class={["flex flex-col gap-1.5", @class]} aria-hidden="true">
      <.card_skeleton :for={i <- 1..@count} :if={@variant == "card"} index={i} />
      <div
        :for={i <- 1..@count}
        :if={@variant == "row"}
        class="h-[38px] animate-shimmer rounded-cta bg-ink/[0.07]"
        style={"animation-delay: #{(i - 1) * 120}ms"}
      />
    </div>
    """
  end

  attr :index, :integer, required: true

  defp card_skeleton(assigns) do
    ~H"""
    <div
      class="animate-shimmer rounded-card border border-ink/8 bg-white p-3.5"
      style={"animation-delay: #{(@index - 1) * 120}ms"}
    >
      <div class="h-2.5 w-[36%] rounded-full bg-ink/10" />
      <div class="mt-2.5 h-4 w-[70%] rounded-md bg-ink/[0.13]" />
      <div class="mt-2 h-2.5 w-1/2 rounded-full bg-ink/[0.08]" />
      <div class="mt-3.5 h-[5px] w-full rounded-full bg-ink/[0.08]" />
    </div>
    """
  end
end

defmodule RolezinhoWeb.Components.UI.AlertBanner do
  @moduledoc """
  A persistent notice at the top of the content.

  Distinct from a toast: a toast confirms something that just happened and
  leaves, while a banner states a condition that is still true (people who have
  not paid, you are on the waitlist). It sits above the content and never over a
  list.
  """
  use Phoenix.Component

  import RolezinhoWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders the banner.

  ## Examples

      <.alert_banner tone="info">3 people have not paid yet.</.alert_banner>
      <.alert_banner tone="warn" action="Charge" action_click="remind">
        3 people have not paid yet.
      </.alert_banner>
  """
  attr :tone, :string, default: "info", values: ~w(info warn danger)
  attr :action, :string, default: nil
  attr :action_click, :any, default: nil
  attr :class, :any, default: nil

  slot :inner_block, required: true

  def alert_banner(assigns) do
    ~H"""
    <div
      role={if @tone == "danger", do: "alert", else: "status"}
      class={["flex items-center gap-2.5 rounded-cta px-3.5 py-3", tone_classes(@tone), @class]}
    >
      <.icon name={icon_for(@tone)} class="size-4 shrink-0" />
      <div class="flex-1 text-xs font-semibold leading-snug">{render_slot(@inner_block)}</div>
      <button
        :if={@action}
        type="button"
        phx-click={@action_click}
        class="shrink-0 cursor-pointer text-[11px] font-bold hover:underline"
      >
        {@action}
      </button>
    </div>
    """
  end

  defp tone_classes("info"), do: "bg-tint text-ink"
  defp tone_classes("warn"), do: "bg-warning/15 text-ink"
  defp tone_classes("danger"), do: "border border-danger/25 bg-white text-ink"

  defp icon_for("info"), do: "tabler-info-circle"
  defp icon_for("warn"), do: "tabler-clock"
  defp icon_for("danger"), do: "tabler-alert-triangle"
end

defmodule RolezinhoWeb.Components.UI.Toast do
  @moduledoc """
  A short confirmation of something that just happened: the key was copied, the
  entry was saved.

  A toast carries no action and does not report conditions that are still true —
  that is `alert_banner/1`. It sits at the bottom, centered, above the primary
  action.
  """
  use Phoenix.Component

  @doc """
  Renders the toast.

  ## Examples

      <.toast :if={@toast} message={@toast} />
  """
  attr :message, :string, required: true
  attr :class, :any, default: nil

  def toast(assigns) do
    ~H"""
    <div
      role="status"
      aria-live="polite"
      class={[
        "pointer-events-none fixed inset-x-0 bottom-[26px] z-50 flex justify-center px-4",
        @class
      ]}
    >
      <span class="rounded-cta bg-ink px-4 py-2.5 text-xs font-semibold whitespace-nowrap text-ink-content shadow-cta">
        {@message}
      </span>
    </div>
    """
  end
end

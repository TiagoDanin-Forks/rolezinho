defmodule RolezinhoWeb.Components.UI.BottomSheet do
  @moduledoc """
  A sheet that rises from the bottom of the screen: join the list, remove,
  share.

  Bottom-anchored because the thumb reaches the bottom of a phone, not the
  middle. A destructive action always sits on the right, in the danger tone.

  Show and hide it with `JS` commands rather than a hook — `JS` is DOM-patch
  aware, so the state survives a re-render from the server (see
  `.claude/rules/liveview.md`).
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders the sheet.

  ## Examples

      <.bottom_sheet id="join" title="Join the list">
        <.text_field label="Name" name="name" />
        <:actions>
          <.action_button phx-click="confirm">Confirm</.action_button>
        </:actions>
      </.bottom_sheet>

      <button phx-click={RolezinhoWeb.Components.UI.BottomSheet.show("join")}>Open</button>
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :open, :boolean, default: false, doc: "renders already open (for stories and tests)"
  attr :on_cancel, JS, default: %JS{}
  attr :class, :any, default: nil

  slot :inner_block
  slot :actions, doc: "the action row at the bottom of the sheet"

  def bottom_sheet(assigns) do
    ~H"""
    <div
      id={@id}
      class={["relative z-50", not @open && "hidden", @class]}
      role="dialog"
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
      phx-window-keydown={hide(@on_cancel, @id)}
      phx-key="escape"
    >
      <div
        id={"#{@id}-backdrop"}
        class="fixed inset-0 bg-ink/45 transition-opacity duration-200"
        aria-hidden="true"
      />
      <div class="fixed inset-x-0 bottom-0 flex justify-center">
        <div
          id={"#{@id}-panel"}
          phx-click-away={hide(@on_cancel, @id)}
          class={[
            "w-full max-w-lg rounded-t-panel bg-white p-4 shadow-sheet",
            "transition-transform duration-[260ms] ease-[cubic-bezier(.2,.8,.2,1)]",
            "motion-reduce:transition-none"
          ]}
        >
          <div class="mx-auto mb-3 h-1 w-9 rounded-full bg-ink/15" aria-hidden="true" />
          <h2 id={"#{@id}-title"} class="text-sm font-extrabold">{@title}</h2>
          <p :if={@description} class="mt-1.5 text-xs leading-relaxed text-muted">
            {@description}
          </p>
          <div :if={@inner_block != []} class="mt-3.5">{render_slot(@inner_block)}</div>
          <div :if={@actions != []} class="mt-3.5 flex gap-2">{render_slot(@actions)}</div>
        </div>
      </div>
    </div>
    """
  end

  @doc "Shows the sheet with the given id."
  def show(js \\ %JS{}, id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-panel",
      transition: {"ease-out duration-[260ms]", "translate-y-full", "translate-y-0"}
    )
  end

  @doc "Hides the sheet with the given id."
  def hide(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-panel",
      transition: {"ease-in duration-200", "translate-y-0", "translate-y-full"}
    )
    |> JS.hide(to: "##{id}", transition: {"duration-200", "opacity-100", "opacity-0"})
  end
end

defmodule RolezinhoWeb.Components.UI.TabBar do
  @moduledoc """
  Fixed bottom navigation between the app's top-level sections.

  Sits inside the phone's safe area: the bottom padding grows to clear the home
  indicator on iOS, so the last tab never ends up under it.
  """
  use Phoenix.Component

  import RolezinhoWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders the tab bar.

  Each tab is a link, so the browser keeps its usual navigation affordances;
  `active` marks the current one through `aria-current`, and the styling follows
  from the attribute rather than a conditional class.

  ## Examples

      <.tab_bar active="events">
        <:tab id="events" icon="tabler-diamond" label="Events" navigate={~p"/"} />
        <:tab id="history" icon="tabler-menu-2" label="History" navigate={~p"/history"} />
        <:tab id="me" icon="tabler-user-circle" label="Me" navigate={~p"/settings"} />
      </.tab_bar>
  """
  attr :active, :string, required: true, doc: "id of the current tab"
  attr :class, :any, default: nil

  slot :tab, required: true do
    attr :id, :string, required: true
    attr :icon, :string, required: true
    attr :label, :string, required: true
    attr :navigate, :string
    attr :badge, :integer
  end

  def tab_bar(assigns) do
    ~H"""
    <!-- The bar spans the window so the surface reads as one edge; the tabs
         inside are capped, because two of them spread across a desktop width
         would sit at opposite corners with nothing between. -->
    <nav
      class={[
        "border-t border-hairline bg-base-100 px-2 pt-2.5",
        "pb-[max(0.75rem,env(safe-area-inset-bottom))]",
        @class
      ]}
      aria-label="Main sections"
    >
      <div class="mx-auto flex w-full max-w-[420px]">
        <.link
          :for={tab <- @tab}
          navigate={tab[:navigate]}
          aria-current={tab.id == @active && "page"}
          class={[
            "relative flex-1 py-1 text-center text-ink/35",
            "aria-[current=page]:text-accent",
            "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
          ]}
        >
          <span class="relative inline-block">
            <.icon name={tab.icon} class="size-[22px]" />
            <span
              :if={tab[:badge] && tab[:badge] > 0}
              class="absolute -right-2 -top-1 grid min-w-4 place-items-center rounded-full bg-accent px-1 text-[9px] font-bold text-accent-content"
            >
              {tab[:badge]}
            </span>
          </span>
          <span class="mt-0.5 block text-[10px] font-bold">{tab.label}</span>
        </.link>
      </div>
    </nav>
    """
  end
end

defmodule RolezinhoWeb.Components.UI.SearchField do
  @moduledoc """
  Search input for filtering a long list by name.

  Filters without reordering: the positions shown keep the numbering they have
  in the full list, because a slot's number is its identity in the event.
  """
  use Phoenix.Component

  import RolezinhoWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders the search field.

  ## Examples

      <.search_field value={@query} placeholder="Find a name in the list" />
  """
  attr :value, :string, default: ""
  attr :placeholder, :string, default: "Search"
  attr :name, :string, default: "q"
  attr :label, :string, default: nil, doc: "accessible name; falls back to the placeholder"
  attr :on_change, :any, default: nil
  attr :on_clear, :any, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  def search_field(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-2.5 rounded-row border border-ink/12 bg-base-100 px-3.5 py-3",
      "focus-within:border-accent focus-within:ring-2 focus-within:ring-accent/20",
      @class
    ]}>
      <.icon name="tabler-search" class="size-[18px] shrink-0 text-ink/35" />
      <input
        type="search"
        name={@name}
        value={@value}
        placeholder={@placeholder}
        aria-label={@label || @placeholder}
        phx-change={@on_change}
        phx-debounce="200"
        class="min-w-0 flex-1 border-0 bg-transparent p-0 text-[13px] font-semibold text-ink outline-none placeholder:font-normal placeholder:text-ink/35 [&::-webkit-search-cancel-button]:hidden"
        {@rest}
      />
      <button
        :if={@value != "" && @on_clear}
        type="button"
        phx-click={@on_clear}
        aria-label="Clear search"
        class="-m-3 grid size-11 shrink-0 place-items-center p-3 text-ink/35 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      >
        <.icon name="tabler-x" class="size-4" />
      </button>
    </div>
    """
  end
end

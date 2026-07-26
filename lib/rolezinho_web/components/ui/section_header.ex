defmodule RolezinhoWeb.Components.UI.SectionHeader do
  @moduledoc """
  Separates the main list from the waitlist, carrying the count.

  The counter is a badge, not running text: it is scanned, not read.
  """
  use Phoenix.Component

  @doc """
  Renders a section header with an optional counter.

  ## Examples

      <.section_header title="Main list" count={17} capacity={18} />
      <.section_header title="Waitlist" count={3} tone="muted" />
  """
  attr :title, :string, required: true
  attr :count, :integer, default: nil
  attr :capacity, :integer, default: nil, doc: "when given, renders as count/capacity"
  attr :tone, :string, default: "strong", values: ~w(strong muted)
  attr :class, :any, default: nil

  def section_header(assigns) do
    ~H"""
    <div class={["flex items-center gap-2.5", @class]}>
      <h2 class={[
        "text-[13px] font-extrabold",
        @tone == "strong" && "text-ink",
        @tone == "muted" && "text-muted"
      ]}>
        {@title}
      </h2>
      <span
        :if={@count}
        class={[
          "rounded-md px-1.5 py-0.5 text-[10px] font-extrabold",
          @tone == "strong" && "bg-ink text-ink-content",
          @tone == "muted" && "bg-ink/10 text-muted"
        ]}
      >
        {if @capacity, do: "#{@count}/#{@capacity}", else: @count}
      </span>
      <span class="h-px flex-1 bg-canvas" />
    </div>
    """
  end
end

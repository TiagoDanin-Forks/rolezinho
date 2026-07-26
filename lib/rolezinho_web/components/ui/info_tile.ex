defmodule RolezinhoWeb.Components.UI.InfoTile do
  @moduledoc """
  A highlighted value (`info_tile/1`) and a labeled detail line
  (`detail_row/1`).

  The tile is what the amount and the Pix key live in: an overline label, the
  value in weight 800, and an optional inline action ("Copy"). A long value never
  wraps — it ellipsizes, so the block keeps its height.
  """
  use Phoenix.Component

  @doc """
  Renders a highlighted value on the warm tint.

  ## Examples

      <.info_tile label="Amount" value="R$ 15" />
      <.info_tile label="Pix key" value="91984933238" action="Copy" phx-click="copy_pix" />
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :action, :string, default: nil, doc: "inline action label; renders a button when given"
  attr :size, :string, default: "md", values: ~w(md lg)
  attr :class, :any, default: nil
  attr :rest, :global

  def info_tile(assigns) do
    ~H"""
    <div class={["rounded-cta bg-tint px-3 py-2.5", @class]}>
      <div class="text-[10px] font-semibold uppercase tracking-wide text-ink/55">
        {@label}
      </div>
      <div class="mt-0.5 flex items-center gap-2">
        <div class={[
          "min-w-0 flex-1 overflow-hidden text-ellipsis whitespace-nowrap font-extrabold",
          @size == "md" && "text-[15px]",
          @size == "lg" && "text-2xl"
        ]}>
          {@value}
        </div>
        <button
          :if={@action}
          type="button"
          class="shrink-0 cursor-pointer text-[11px] font-bold text-accent hover:underline"
          {@rest}
        >
          {@action}
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a labeled detail line, marked by a small orange dot.

  Rows are meant to be stacked inside a single bordered container; pass
  `divider={false}` on the last one.

  ## Examples

      <div class="rounded-cta border border-ink/8 bg-white px-3.5">
        <.detail_row label="Where" value="Rua Caripunas" />
        <.detail_row label="When" value="Wednesday, 7pm" divider={false} />
      </div>
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :divider, :boolean, default: true
  attr :class, :any, default: nil

  def detail_row(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-3 py-2.5",
      @divider && "border-b border-ink/8",
      @class
    ]}>
      <span class="size-2 shrink-0 rounded-full bg-accent" />
      <div>
        <div class="text-[11px] text-ink/55">{@label}</div>
        <div class="text-[13px] font-bold">{@value}</div>
      </div>
    </div>
    """
  end
end

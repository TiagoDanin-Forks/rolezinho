defmodule RolezinhoWeb.Components.UI.SegmentedControl do
  @moduledoc """
  A choice among up to three short options.

  Past three options the labels stop fitting on a phone — use a select instead.
  """
  use Phoenix.Component

  @doc """
  Renders the segmented control.

  Each option is a `{value, label}` tuple.

  ## Examples

      <.segmented_control
        name="field_type"
        value={@type}
        options={[{"text", "Text"}, {"tel", "Phone"}, {"number", "Number"}]}
        change="set_type"
      />
  """
  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :options, :list, required: true, doc: "a list of {value, label} tuples"
  attr :change, :any, required: true, doc: "phx-click for each option"
  attr :class, :any, default: nil

  def segmented_control(assigns) do
    ~H"""
    <div class={["flex gap-1.5", @class]} role="radiogroup" aria-label={@name}>
      <button
        :for={{value, label} <- @options}
        type="button"
        role="radio"
        aria-checked={to_string(value == @value)}
        phx-click={@change}
        phx-value-value={value}
        class={[
          "min-h-11 flex-1 rounded-row px-3 py-2.5 text-xs font-bold transition",
          if(value == @value,
            do: "bg-ink text-ink-content",
            else: "bg-white text-muted hover:bg-surface"
          )
        ]}
      >
        {label}
      </button>
    </div>
    """
  end
end

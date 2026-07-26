defmodule RolezinhoWeb.Components.UI.FieldConfigRow do
  @moduledoc """
  One field of the join form, as configured by the organizer.

  Locked fields show a padlock instead of a remove button: name identifies the
  person in the list, so removing it would leave rows with nothing to display.
  Every extra field costs conversion, which is why the default form is short and
  each addition is an explicit choice.
  """
  use Phoenix.Component

  import RolezinhoWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders the row.

  ## Examples

      <.field_config_row label="Number (WhatsApp)" type="tel" required locked />
      <.field_config_row label="Shirt (S/M/L)" type="text" on_remove={JS.push("remove_field")} />
  """
  attr :label, :string, required: true
  attr :type, :string, default: "text", values: ~w(text tel number)
  attr :required, :boolean, default: false
  attr :locked, :boolean, default: false, doc: "locked fields cannot be removed or made optional"
  attr :on_toggle_required, :any, default: nil
  attr :on_remove, :any, default: nil
  attr :value, :string, default: nil, doc: "field id, sent as phx-value-id"
  attr :class, :any, default: nil

  def field_config_row(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-2.5 rounded-card border border-hairline bg-base-100 px-3.5 py-3",
      @class
    ]}>
      <div class="min-w-0 flex-1">
        <div class="truncate text-[13px] font-bold">{@label}</div>
        <div class="mt-0.5 text-[10.5px] text-ink/45">{type_label(@type)}</div>
      </div>

      <button
        type="button"
        disabled={@locked}
        phx-click={!@locked && @on_toggle_required}
        phx-value-id={@value}
        aria-pressed={to_string(@required)}
        class={[
          "shrink-0 rounded-lg px-2.5 py-1.5 text-[9.5px] font-bold uppercase tracking-wide",
          "bg-ink/[0.08] text-ink/55 aria-pressed:bg-accent aria-pressed:text-accent-content",
          "disabled:cursor-default",
          "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        ]}
      >
        {if @required, do: "Required", else: "Optional"}
      </button>

      <span :if={@locked} class="grid size-11 shrink-0 place-items-center text-ink/25">
        <.icon name="tabler-lock" class="size-4" />
      </span>
      <button
        :if={!@locked}
        type="button"
        phx-click={@on_remove}
        phx-value-id={@value}
        aria-label={"Remove field #{@label}"}
        class="grid size-11 shrink-0 place-items-center text-ink/35 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
      >
        <.icon name="tabler-x" class="size-4" />
      </button>
    </div>
    """
  end

  defp type_label("text"), do: "Text"
  defp type_label("tel"), do: "Phone"
  defp type_label("number"), do: "Number"
end

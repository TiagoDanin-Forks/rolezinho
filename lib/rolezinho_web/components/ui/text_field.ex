defmodule RolezinhoWeb.Components.UI.TextField do
  @moduledoc """
  A labeled text input (`text_field/1`) and the event password input
  (`password_field/1`).

  The label sits above the field and there is no decorative placeholder: a
  placeholder that repeats the label disappears the moment someone starts typing,
  exactly when they still need it.

  The password field is deliberately large and letter-spaced — it is transcribed
  from a group chat message, often wrong the first time, so the error text says
  what to do rather than only what failed.
  """
  use Phoenix.Component

  @doc """
  Renders a labeled text input.

  ## Examples

      <.text_field label="Name" name="name" value={@name} required />
      <.text_field label="Phone" name="phone" type="tel" error="Missing the area code." />
  """
  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :type, :string, default: "text", values: ~w(text tel number email)
  attr :required, :boolean, default: false
  attr :error, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled readonly autocomplete inputmode maxlength placeholder)

  def text_field(assigns) do
    assigns = assign(assigns, :id, assigns.rest[:id] || "field-#{assigns.name}")

    ~H"""
    <div class={@class}>
      <label for={@id} class="mb-1 block text-[11px] font-bold text-ink/55">
        {@label}<span :if={@required} aria-hidden="true">&nbsp;*</span>
      </label>
      <input
        type={@type}
        id={@id}
        name={@name}
        value={@value}
        required={@required}
        aria-invalid={@error && "true"}
        aria-describedby={@error && "#{@id}-error"}
        class={[
          "w-full min-h-11 rounded-row border bg-white px-3.5 py-3",
          "text-[13px] font-semibold text-ink",
          "focus:outline-2 focus:outline-offset-0 focus:outline-accent",
          if(@error, do: "border-danger", else: "border-ink/15")
        ]}
        {@rest}
      />
      <p :if={@error} id={"#{@id}-error"} class="mt-1.5 text-[11px] font-bold text-danger">
        {@error}
      </p>
    </div>
    """
  end

  @doc """
  Renders the event password input.

  ## Examples

      <.password_field label="List password" name="password" />
      <.password_field
        label="List password"
        name="password"
        error="Wrong password. Check with whoever invited you."
      />
  """
  attr :label, :string, default: "List password"
  attr :name, :string, default: "password"
  attr :value, :string, default: ""
  attr :error, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled autocomplete maxlength placeholder autofocus)

  def password_field(assigns) do
    assigns = assign(assigns, :id, assigns.rest[:id] || "field-#{assigns.name}")

    ~H"""
    <div class={@class}>
      <label for={@id} class="mb-1 block text-[11px] font-bold text-ink/55">{@label}</label>
      <input
        type="text"
        id={@id}
        name={@name}
        value={@value}
        aria-invalid={@error && "true"}
        aria-describedby={@error && "#{@id}-error"}
        class={[
          "w-full min-h-11 border-0 border-b-2 bg-transparent px-0 py-1.5",
          "text-lg font-extrabold tracking-[2px] text-ink",
          "focus:outline-none focus:border-accent",
          if(@error, do: "border-danger", else: "border-ink/8")
        ]}
        {@rest}
      />
      <p :if={@error} id={"#{@id}-error"} class="mt-2 text-[11px] font-bold text-danger">
        {@error}
      </p>
    </div>
    """
  end
end

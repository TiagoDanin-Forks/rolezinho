defmodule RolezinhoWeb.Components.UI.Avatar do
  @moduledoc """
  Initial-based avatars (`avatar/1`) and the overlapping group that shows who is
  already in (`avatar_stack/1`).

  There are no uploaded pictures in this product: an avatar is the first letter
  of the name over a color derived from the name itself, so the same person keeps
  the same color across screens without anything being stored.
  """
  use Phoenix.Component

  @doc """
  Renders a single avatar.

  ## Examples

      <.avatar name="Marcia" />
      <.avatar name="Henrique" size="lg" />
  """
  attr :name, :string, required: true
  attr :size, :string, default: "md", values: ~w(xs sm md lg)
  attr :class, :any, default: nil
  attr :rest, :global

  def avatar(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex shrink-0 items-center justify-center rounded-full font-bold text-white",
        size_classes(@size),
        @class
      ]}
      style={"background-color: #{color_for(@name)}"}
      title={@name}
      {@rest}
    >
      {initial(@name)}
    </span>
    """
  end

  @doc """
  Renders overlapping avatars, with a `+N` counter past `max`.

  ## Examples

      <.avatar_stack names={["Marcia", "Robertinha", "Henrique"]} />
      <.avatar_stack names={@confirmed} max={4} />
  """
  attr :names, :list, required: true
  attr :max, :integer, default: 6
  attr :size, :string, default: "sm", values: ~w(xs sm md lg)

  attr :ring_class, :string,
    default: "ring-white",
    doc: "the color the separating ring blends into — match the surface behind the stack"

  attr :class, :any, default: nil

  def avatar_stack(assigns) do
    shown = Enum.take(assigns.names, assigns.max)

    assigns =
      assign(assigns, shown: shown, overflow: length(assigns.names) - length(shown))

    ~H"""
    <div class={["flex items-center", @class]}>
      <.avatar
        :for={name <- @shown}
        name={name}
        size={@size}
        class={["ring-2 not-first:-ml-2", @ring_class]}
      />
      <span
        :if={@overflow > 0}
        class={[
          "inline-flex shrink-0 items-center justify-center rounded-full",
          "bg-ink/[0.12] font-bold text-ink/60 ring-2 -ml-2",
          size_classes(@size),
          @ring_class
        ]}
      >
        +{@overflow}
      </span>
    </div>
    """
  end

  defp size_classes("xs"), do: "size-6 text-[10px]"
  defp size_classes("sm"), do: "size-8 text-[13px]"
  defp size_classes("md"), do: "size-9 text-[13px]"
  defp size_classes("lg"), do: "size-11 text-base"

  defp initial(name) do
    name
    |> String.trim()
    |> String.first()
    |> case do
      nil -> "?"
      letter -> String.upcase(letter)
    end
  end

  # Hue derived from the name so a person keeps their color without any storage.
  # The lightness and chroma are fixed, which keeps white text legible on every
  # hue the hash can produce.
  defp color_for(name) do
    hue = :erlang.phash2(String.downcase(String.trim(name)), 360)
    "oklch(68% 0.14 #{hue})"
  end
end

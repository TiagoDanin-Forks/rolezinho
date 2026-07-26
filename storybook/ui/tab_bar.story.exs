defmodule Storybook.UI.TabBar do
  use PhoenixStorybook.Story, :component

  def function, do: &RolezinhoWeb.Components.UI.TabBar.tab_bar/1

  def template do
    """
    <div class="rounded-cta bg-surface p-3.5 pt-8" psb-code-hidden>
      <.psb-variation/>
    </div>
    """
  end

  defp tabs do
    [
      %{id: "events", icon: "tabler-diamond", label: "Events", navigate: "/"},
      %{id: "history", icon: "tabler-menu-2", label: "History", navigate: "/"},
      %{id: "me", icon: "tabler-user-circle", label: "Me", navigate: "/"}
    ]
  end

  def variations do
    [
      %Variation{
        id: :default,
        description: "The bottom padding grows to clear the iOS home indicator.",
        attributes: %{active: "events"},
        slots: Enum.map(tabs(), &tab_slot/1)
      },
      %Variation{
        id: :with_badge,
        description: "A badge marks a section with something waiting.",
        attributes: %{active: "me"},
        slots:
          tabs()
          |> List.update_at(1, &Map.put(&1, :badge, 3))
          |> Enum.map(&tab_slot/1)
      }
    ]
  end

  defp tab_slot(tab) do
    badge = if tab[:badge], do: ~s( badge="#{tab.badge}"), else: ""

    ~s(<:tab id="#{tab.id}" icon="#{tab.icon}" label="#{tab.label}" navigate="#{tab.navigate}"#{badge} />)
  end
end

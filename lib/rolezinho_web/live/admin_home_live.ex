defmodule RolezinhoWeb.AdminHomeLive do
  @moduledoc "Admin dashboard: lists rolezinhos in every status."
  use RolezinhoWeb, :live_view

  alias Rolezinho.Events

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Events.subscribe_home()

    {:ok,
     socket
     |> assign(:page_title, "Painel do admin")
     |> load_all()}
  end

  @impl true
  def handle_info(:home_changed, socket), do: {:noreply, load_all(socket)}

  defp load_all(socket) do
    socket
    |> assign(:active_events, Events.list_active())
    |> assign(:hidden_events, Events.list_hidden())
    |> assign(:done_events, Events.list_done())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_admin?={@current_admin?} page_title={@page_title}>
      <div class="flex items-end justify-between gap-4 flex-wrap mb-8">
        <div>
          <h1 class="text-3xl sm:text-4xl font-bold tracking-tight">Painel do admin</h1>
          <p class="mt-2 text-base-content/70">Gerencie todos os rolezinhos aqui.</p>
        </div>
        <.link navigate={~p"/admin/new"} class="btn btn-primary">
          <.icon name="hero-plus" class="size-4" /> Criar rolezinho
        </.link>
      </div>

      <.event_section title="Ativos" empty="Nenhum rolezinho ativo." events={@active_events} />
      <.event_section title="Ocultos" empty="Nenhum rolezinho oculto." events={@hidden_events} />
      <.event_section title="Concluídos" empty="Nenhum rolezinho concluído." events={@done_events} />
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :empty, :string, required: true
  attr :events, :list, required: true

  defp event_section(assigns) do
    ~H"""
    <section class="mb-10">
      <h2 class="text-xl font-semibold mb-3">{@title}</h2>

      <div
        :if={@events == []}
        class="rounded-xl border border-dashed border-base-300 p-6 text-sm text-base-content/60"
      >
        {@empty}
      </div>

      <ul :if={@events != []} class="space-y-2">
        <li
          :for={event <- @events}
          class="flex items-center justify-between gap-3 rounded-xl border border-base-300 bg-base-100 p-4 hover:border-primary/50 transition-colors"
        >
          <div class="min-w-0">
            <p class="font-medium truncate">{event.title}</p>
            <p class="text-xs text-base-content/60 truncate">/r/{event.slug}</p>
          </div>
          <div class="flex items-center gap-2 shrink-0">
            <.link navigate={~p"/r/#{event.slug}"} class="btn btn-sm btn-ghost">Abrir</.link>
            <.link navigate={~p"/admin/r/#{event.slug}/edit"} class="btn btn-sm btn-outline">Editar</.link>
          </div>
        </li>
      </ul>
    </section>
    """
  end
end

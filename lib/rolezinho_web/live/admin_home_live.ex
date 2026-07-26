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

  @impl true
  def handle_event("clone", %{"slug" => slug}, socket) do
    with event when not is_nil(event) <- Rolezinho.Events.find(slug),
         {:ok, clone} <- Rolezinho.Events.clone(event) do
      {:noreply,
       socket
       |> put_flash(:info, "Rolezinho clonado. Ajuste e salve.")
       |> push_navigate(to: ~p"/admin/r/#{clone.slug}/edit")}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Não deu pra clonar.")}
    end
  end

  defp load_all(socket) do
    socket
    |> assign(:active_events, Events.list_active())
    |> assign(:payments_only_events, Events.list_payments_only())
    |> assign(:hidden_events, Events.list_hidden())
    |> assign(:done_events, Events.list_done())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_admin?={@current_admin?}
      page_title={@page_title}
      tabs?={false}
    >
      <div class="flex items-end justify-between gap-4 flex-wrap mb-8">
        <div>
          <h1 class="text-3xl sm:text-4xl font-bold tracking-tight">Painel do admin</h1>
          <p class="mt-2 text-base-content/70">Gerencie todos os rolezinhos aqui.</p>
        </div>
        <.link
          navigate={~p"/admin/new"}
          class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm bg-primary text-primary-content hover:bg-primary/90"
        >
          <.icon name="tabler-plus" class="size-4" /> Criar rolezinho
        </.link>
      </div>

      <.event_section title="Ativos" empty="Nenhum rolezinho ativo." events={@active_events} />
      <.event_section
        title="Só pagamentos"
        empty="Nenhum rolezinho em modo só pagamentos."
        events={@payments_only_events}
      />
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
            <.link
              navigate={~p"/r/#{event.slug}"}
              class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 hover:bg-base-200"
            >Abrir</.link>
            <.link
              navigate={~p"/admin/r/#{event.slug}/edit"}
              class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 bg-primary text-primary-content hover:bg-primary/90"
            >
              Editar
            </.link>
            <span class="h-6 w-px bg-base-300 mx-1" aria-hidden="true" />
            <button
              type="button"
              phx-click="clone"
              phx-value-slug={event.slug}
              data-confirm={"Criar uma cópia de \"" <> event.title <> "\"?"}
              class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 border border-base-300 hover:bg-base-200"
              title="Clonar"
            >
              <.icon name="tabler-copy" class="size-4" /> Clonar
            </button>
          </div>
        </li>
      </ul>
    </section>
    """
  end
end

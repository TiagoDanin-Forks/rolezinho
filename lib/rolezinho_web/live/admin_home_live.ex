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
    >
      <div class="mx-auto max-w-[420px]">
        <header class="flex items-center justify-between gap-3">
          <div>
            <h1 class="text-2xl font-extrabold tracking-tight">Painel</h1>
            <p class="mt-0.5 text-[13px] text-muted">Todos os rolês, em qualquer estado.</p>
          </div>
          <.link
            navigate={~p"/admin/new"}
            class="grid size-11 shrink-0 place-items-center rounded-full bg-ink text-ink-content shadow-cta focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
            aria-label="Criar rolezinho"
          >
            <.icon name="tabler-plus" class="size-5" />
          </.link>
        </header>

        <!-- Empty sections are dropped rather than shown as placeholders: with
             four states, a panel of "nenhum" lines says less than a short list
             of what actually exists. -->
        <.event_section title="Ativos" events={@active_events} />
        <.event_section title="Só pagamentos" events={@payments_only_events} />
        <.event_section title="Ocultos" events={@hidden_events} />
        <.event_section title="Concluídos" events={@done_events} />

        <.empty_state
          :if={everything_empty?(assigns)}
          icon="tabler-diamond"
          title="Nenhum rolê ainda"
          class="mt-6"
        >
          Crie o primeiro e mande o link no grupo.
        </.empty_state>
      </div>
    </Layouts.app>
    """
  end

  defp everything_empty?(assigns) do
    Enum.all?(
      [
        assigns.active_events,
        assigns.payments_only_events,
        assigns.hidden_events,
        assigns.done_events
      ],
      &(&1 == [])
    )
  end

  attr :title, :string, required: true
  attr :events, :list, required: true

  defp event_section(assigns) do
    ~H"""
    <section :if={@events != []} class="mt-6">
      <.section_header title={@title} count={length(@events)} />

      <ul class="mt-2 space-y-2">
        <li
          :for={event <- @events}
          class="flex items-center gap-2.5 rounded-card border border-hairline bg-base-100 p-3.5 shadow-card"
        >
          <.link navigate={~p"/r/#{event.slug}"} class="min-w-0 flex-1">
            <p class="truncate text-[13px] font-bold">{event.title}</p>
            <p class="truncate font-mono text-[11px] text-muted">/r/{event.slug}</p>
          </.link>
          <.link
            navigate={~p"/admin/r/#{event.slug}/edit"}
            class="grid size-11 shrink-0 place-items-center rounded-full bg-ink/[0.06] text-ink"
            aria-label={"Editar #{event.title}"}
          >
            <.icon name="tabler-pencil" class="size-4" />
          </.link>
          <button
            type="button"
            phx-click="clone"
            phx-value-slug={event.slug}
            data-confirm={"Criar uma cópia de \"" <> event.title <> "\"?"}
            class="grid size-11 shrink-0 place-items-center rounded-full bg-ink/[0.06] text-ink"
            aria-label={"Clonar #{event.title}"}
          >
            <.icon name="tabler-copy" class="size-4" />
          </button>
        </li>
      </ul>
    </section>
    """
  end
end

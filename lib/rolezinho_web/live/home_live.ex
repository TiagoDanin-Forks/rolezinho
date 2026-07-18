defmodule RolezinhoWeb.HomeLive do
  @moduledoc "Public home page listing active rolezinhos."
  use RolezinhoWeb, :live_view

  alias Rolezinho.Event
  alias Rolezinho.Events

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Events.subscribe_home()

    {:ok,
     socket
     |> assign(:page_title, "Rolezinhos")
     |> load_events()}
  end

  @impl true
  def handle_info(:home_changed, socket) do
    {:noreply, load_events(socket)}
  end

  defp load_events(socket) do
    assign(socket, :events, Events.list_open())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_admin?={@current_admin?} page_title={@page_title}>
      <section class="mb-10">
        <div class="flex items-end justify-between gap-4 flex-wrap">
          <div>
            <h1 class="text-3xl sm:text-4xl font-bold tracking-tight">Rolezinhos abertos</h1>
            <p class="mt-2 text-base-content/70">
              Escolha um evento pra entrar na lista.
            </p>
          </div>

          <.link :if={@current_admin?} navigate={~p"/admin/new"} class="btn btn-primary">
            <.icon name="hero-plus" class="size-4" /> Criar rolezinho
          </.link>
        </div>
      </section>

      <section
        :if={@events == []}
        class="rounded-2xl border border-dashed border-base-300 p-10 text-center"
      >
        <p class="text-base-content/60">
          Nenhum rolezinho ativo por aqui.
          <span :if={@current_admin?}>Que tal <.link class="link" navigate={~p"/admin/new"}>criar o primeiro</.link>?</span>
        </p>
      </section>

      <ul :if={@events != []} class="grid gap-4 sm:grid-cols-2">
        <li :for={event <- @events}>
          <.link
            navigate={~p"/r/#{event.slug}"}
            class="group block rounded-2xl border border-base-300 bg-base-100 p-5 hover:border-primary hover:shadow-lg transition-all"
          >
            <div class="flex items-center justify-between gap-3">
              <h2 class="text-lg font-semibold group-hover:text-primary transition-colors line-clamp-2">
                {event.title}
              </h2>
              <span class="text-xs text-base-content/50">/r/{event.slug}</span>
            </div>

            <p class="mt-2 text-sm text-base-content/70">
              {filled_count(event)} / {event.main_capacity} na lista principal
              <span :if={event.wait_enabled} class="text-base-content/50">
                · {length(event.wait_list)} na reserva
              </span>
            </p>

            <div class="mt-4 flex flex-wrap items-center gap-2 text-xs">
              <span class={[
                "px-2 py-0.5 rounded-full font-medium",
                cond do
                  event.status == :payments_only -> "bg-info/20 text-info"
                  Event.main_full?(event) -> "bg-warning/20 text-warning-content"
                  true -> "bg-success/20 text-success"
                end
              ]}>
                <%= cond do %>
                  <% event.status == :payments_only -> %>
                    Só pagamentos
                  <% Event.main_full?(event) -> %>
                    Lotado
                  <% true -> %>
                    Tem vaga
                <% end %>
              </span>
              <span
                :if={Event.password_protected?(event)}
                class="px-2 py-0.5 rounded-full font-medium bg-base-300 text-base-content"
              >
                Com senha
              </span>
            </div>
          </.link>
        </li>
      </ul>
    </Layouts.app>
    """
  end

  defp filled_count(%Event{main_list: list}) do
    Enum.count(list, fn a -> String.trim(a.name) != "" end)
  end
end

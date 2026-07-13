defmodule RolezinhoWeb.EventEditLive do
  @moduledoc "Admin raw markdown editor for an event."
  use RolezinhoWeb, :live_view

  alias Rolezinho.Event
  alias Rolezinho.Events

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Events.find(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Rolezinho não encontrado.")
         |> push_navigate(to: ~p"/admin")}

      event ->
        content = Event.render(event)

        {:ok,
         socket
         |> assign(:page_title, "Editar #{event.title}")
         |> assign(:event, event)
         |> assign(:content, content)
         |> assign(:main_size_input, to_string(event.main_capacity))}
    end
  end

  @impl true
  def handle_event("update_content", %{"content" => content}, socket) do
    {:noreply, assign(socket, :content, content)}
  end

  def handle_event("save", %{"content" => content}, socket) do
    case Events.save_raw(socket.assigns.event, content) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Salvo!")
         |> assign(:event, event)
         |> assign(:content, Event.render(event))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Não deu pra salvar: #{inspect(reason)}")}
    end
  end

  def handle_event("resize_main", %{"main_size" => size}, socket) do
    case Integer.parse(String.trim(size)) do
      {n, ""} when n >= 1 and n <= 500 ->
        {:ok, event} = Events.resize_main(socket.assigns.event, n)

        {:noreply,
         socket
         |> put_flash(:info, "Tamanho da lista atualizado.")
         |> assign(:event, event)
         |> assign(:content, Event.render(event))
         |> assign(:main_size_input, to_string(event.main_capacity))}

      _ ->
        {:noreply, put_flash(socket, :error, "Tamanho inválido.")}
    end
  end

  def handle_event("set_status", %{"status" => status}, socket) do
    status_atom = String.to_existing_atom(status)
    {:ok, event} = Events.set_status(socket.assigns.event, status_atom)

    {:noreply,
     socket
     |> put_flash(:info, "Status atualizado.")
     |> assign(:event, event)}
  end

  def handle_event("delete", _params, socket) do
    :ok = Events.delete(socket.assigns.event)

    {:noreply,
     socket
     |> put_flash(:info, "Rolezinho apagado.")
     |> push_navigate(to: ~p"/admin")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_admin?={@current_admin?} page_title={@page_title}>
      <div class="mb-6 flex items-center justify-between gap-3 flex-wrap">
        <div>
          <p class="text-xs text-base-content/50">/r/{@event.slug} · status: {@event.status}</p>
          <h1 class="text-3xl font-bold tracking-tight">Editar rolezinho</h1>
        </div>
        <.link navigate={~p"/r/#{@event.slug}"} class="btn btn-sm btn-ghost">
          <.icon name="hero-arrow-left" class="size-4" /> Voltar
        </.link>
      </div>

      <section class="rounded-2xl border border-base-300 bg-base-100 p-5 mb-6">
        <h2 class="font-semibold mb-3">Texto do rolezinho</h2>
        <p class="text-xs text-base-content/60 mb-3">
          Edite livremente. O parser reconhece o título (# ...), a lista principal (linhas numeradas), a lista de reserva
          (segunda lista numerada) e o marcador ✅ para pagamentos.
        </p>

        <form phx-change="update_content" phx-submit="save" id="raw-edit-form">
          <textarea
            name="content"
            id="event-content"
            rows="24"
            class="w-full textarea textarea-bordered font-mono text-sm leading-relaxed"
            phx-debounce="500"
          >{@content}</textarea>
          <div class="mt-3 flex gap-3">
            <button type="submit" class="btn btn-primary">Salvar texto</button>
          </div>
        </form>
      </section>

      <section class="rounded-2xl border border-base-300 bg-base-100 p-5 mb-6">
        <h2 class="font-semibold mb-3">Tamanho da lista principal</h2>
        <form phx-submit="resize_main" class="flex items-end gap-3">
          <div class="flex-1 max-w-40">
            <.input
              type="number"
              name="main_size"
              id="main-size-input"
              value={@main_size_input}
              min="1"
              max="500"
              label="Vagas"
            />
          </div>
          <button type="submit" class="btn btn-outline mb-2">Atualizar</button>
        </form>
        <p class="text-xs text-base-content/60 mt-2">
          Não é possível reduzir abaixo de quantas pessoas já estão na lista. Atualmente: {filled_count(
            @event
          )}.
        </p>
      </section>

      <section class="rounded-2xl border border-base-300 bg-base-100 p-5 mb-6">
        <h2 class="font-semibold mb-3">Status</h2>
        <div class="flex flex-wrap gap-2">
          <button
            :for={status <- [:active, :hidden, :done]}
            type="button"
            phx-click="set_status"
            phx-value-status={to_string(status)}
            disabled={@event.status == status}
            class={[
              "btn btn-sm",
              if(@event.status == status, do: "btn-primary", else: "btn-outline")
            ]}
          >
            {status_label(status)}
          </button>
        </div>
        <p class="text-xs text-base-content/60 mt-3">
          <strong>Ativo:</strong>
          aparece na página inicial. <strong>Oculto:</strong>
          não aparece, mas acessível pelo link. <strong>Concluído:</strong>
          arquivado, apenas o admin acessa.
        </p>
      </section>

      <section class="rounded-2xl border border-error/40 bg-error/5 p-5">
        <h2 class="font-semibold text-error mb-2">Zona perigosa</h2>
        <p class="text-sm text-base-content/70 mb-3">
          Apagar remove o arquivo permanentemente. Não dá pra desfazer.
        </p>
        <button
          type="button"
          phx-click="delete"
          data-confirm="Apagar este rolezinho? Isso é permanente."
          class="btn btn-error btn-sm"
        >
          Apagar rolezinho
        </button>
      </section>
    </Layouts.app>
    """
  end

  defp status_label(:active), do: "Ativo"
  defp status_label(:hidden), do: "Oculto"
  defp status_label(:done), do: "Concluído"

  defp filled_count(%Event{main_list: list}) do
    Enum.count(list, fn a -> String.trim(a.name) != "" end)
  end
end

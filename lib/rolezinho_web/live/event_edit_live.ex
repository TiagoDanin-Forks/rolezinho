defmodule RolezinhoWeb.EventEditLive do
  @moduledoc "Admin raw markdown editor for an event."
  use RolezinhoWeb, :live_view

  alias Rolezinho.Event
  alias Rolezinho.Event.Meta
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
        {:ok,
         socket
         |> assign(:page_title, "Editar #{event.title}")
         |> assign_event(event)}
    end
  end

  defp assign_event(socket, %Event{} = event) do
    {meta, _rest} = Meta.extract(event.header)

    socket
    |> assign(:event, event)
    |> assign(:content, Event.render(event))
    |> assign(:main_size_input, to_string(event.main_capacity))
    |> assign(:slug_input, event.slug)
    |> assign(:password_input, event.password || "")
    |> assign(:meta_form, to_form(Meta.to_form_params(meta), as: :meta))
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
         |> assign_event(event)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Não deu pra salvar: #{inspect(reason)}")}
    end
  end

  def handle_event("save_meta", %{"meta" => params}, socket) do
    case Events.update_meta(socket.assigns.event, params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Data, horário e local atualizados.")
         |> assign_event(event)}

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
         |> assign_event(event)}

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
     |> assign_event(event)}
  end

  def handle_event("delete", _params, socket) do
    :ok = Events.delete(socket.assigns.event)

    {:noreply,
     socket
     |> put_flash(:info, "Rolezinho apagado.")
     |> push_navigate(to: ~p"/admin")}
  end

  def handle_event("update_slug_input", %{"slug" => slug}, socket) do
    {:noreply, assign(socket, :slug_input, slug)}
  end

  def handle_event("update_password_input", %{"password" => password}, socket) do
    {:noreply, assign(socket, :password_input, password)}
  end

  def handle_event("save_password", %{"password" => password}, socket) do
    case Events.update_password(socket.assigns.event, password) do
      {:ok, event} ->
        message =
          if Event.password_protected?(event),
            do: "Senha atualizada.",
            else: "Senha removida."

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> assign_event(event)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Não deu pra salvar: #{inspect(reason)}")}
    end
  end

  def handle_event("rename_slug", %{"slug" => new_slug}, socket) do
    case Events.rename_slug(socket.assigns.event, new_slug) do
      {:ok, %Event{slug: same} = event} when same == socket.assigns.event.slug ->
        {:noreply, assign_event(socket, event)}

      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Slug atualizado.")
         |> push_navigate(to: ~p"/admin/r/#{event.slug}/edit")}

      {:error, :invalid_slug} ->
        {:noreply,
         socket
         |> put_flash(:error, "Slug inválido. Use letras minúsculas, números e traços.")
         |> assign(:slug_input, new_slug)}

      {:error, :slug_taken} ->
        {:noreply,
         socket
         |> put_flash(:error, "Esse slug já está em uso.")
         |> assign(:slug_input, new_slug)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Não deu pra renomear: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_admin?={@current_admin?}
      page_title={@page_title}
    >
      <header class="mb-5 flex items-center gap-2">
        <.link
          navigate={~p"/r/#{@event.slug}"}
          class="grid size-11 shrink-0 place-items-center rounded-full bg-ink/[0.06] text-ink"
          aria-label="Voltar pro rolê"
        >
          <.icon name="tabler-arrow-left" class="size-[18px]" />
        </.link>
        <div class="min-w-0">
          <h1 class="text-2xl font-extrabold tracking-tight">Editar</h1>
          <p class="truncate font-mono text-[11px] text-muted">
            /r/{@event.slug} · {@event.status}
          </p>
        </div>
      </header>

      <section class="rounded-card border border-hairline bg-base-100 p-4 shadow-card mb-3">
        <h2 class="text-[13px] font-extrabold mb-3">Slug (URL)</h2>
        <p class="text-[11px] text-muted mb-3">
          Trocar o slug muda a URL do rolezinho. Links antigos deixam de funcionar.
        </p>

        <form
          phx-submit="rename_slug"
          phx-change="update_slug_input"
          id="slug-form"
          class="flex flex-wrap items-end gap-3"
        >
          <label class="flex-1 min-w-64">
            <span class="label text-sm mb-1">Novo slug</span>
            <div class="inline-flex -space-x-px w-full">
              <span class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 rounded-none first:rounded-l-md last:rounded-r-md pointer-events-none font-mono text-xs sm:text-sm">/r/</span>
              <input
                type="text"
                name="slug"
                id="slug-input"
                value={@slug_input}
                class={[
                  field_class(),
                  "rounded-none first:rounded-l-md last:rounded-r-md flex-1 font-mono"
                ]}
                pattern="[a-z0-9](?:[a-z0-9-]{0,60}[a-z0-9])?"
                required
              />
            </div>
          </label>
          <button
            type="submit"
            class="rounded-row bg-ink px-4 py-2.5 text-xs font-bold text-ink-content transition-transform active:scale-[.97] disabled:opacity-40 disabled:pointer-events-none"
            disabled={@slug_input == @event.slug}
          >
            Salvar slug
          </button>
        </form>
      </section>

      <section class="rounded-card border border-hairline bg-base-100 p-4 shadow-card mb-3">
        <h2 class="text-[13px] font-extrabold mb-3">Quando &amp; onde</h2>
        <p class="text-xs text-base-content/60 mb-4">
          Data e horário no fuso de Brasília (BRT). Todos os campos são opcionais.
        </p>

        <.form for={@meta_form} id="meta-form" phx-submit="save_meta" class="space-y-4">
          <.input field={@meta_form[:local]} label="Local" placeholder="ex.: Rua Caripunas" />

          <div class="grid grid-cols-2 gap-4">
            <.input field={@meta_form[:date]} type="date" label="Data (BRT)" />
            <.input field={@meta_form[:time]} type="time" label="Horário (BRT)" />
          </div>

          <div>
            <button
              type="submit"
              class="rounded-row bg-ink px-4 py-2.5 text-xs font-bold text-ink-content transition-transform active:scale-[.97] disabled:opacity-40 disabled:pointer-events-none"
            >Salvar quando &amp; onde</button>
          </div>
        </.form>
      </section>

      <section class="rounded-card border border-hairline bg-base-100 p-4 shadow-card mb-3">
        <h2 class="text-[13px] font-extrabold mb-3">Texto do rolezinho</h2>
        <p class="text-[11px] text-muted mb-3">
          Edite livremente. O parser reconhece o título (# ...), a lista principal (linhas numeradas), a lista de reserva
          (segunda lista numerada) e o marcador ✅ para pagamentos.
        </p>

        <form phx-change="update_content" phx-submit="save" id="raw-edit-form">
          <textarea
            name="content"
            id="event-content"
            rows="24"
            class={["w-full font-mono leading-relaxed", field_class()]}
            phx-debounce="500"
          >{@content}</textarea>
          <div class="mt-3 flex gap-3">
            <button
              type="submit"
              class="rounded-row bg-ink px-4 py-2.5 text-xs font-bold text-ink-content transition-transform active:scale-[.97] disabled:opacity-40 disabled:pointer-events-none"
            >Salvar texto</button>
          </div>
        </form>
      </section>

      <section class="rounded-card border border-hairline bg-base-100 p-4 shadow-card mb-3">
        <h2 class="text-[13px] font-extrabold mb-3">Tamanho da lista principal</h2>
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
          <button
            type="submit"
            class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm border border-base-300 hover:bg-base-200 mb-2"
          >Atualizar</button>
        </form>
        <p class="text-xs text-base-content/60 mt-2">
          Não é possível reduzir abaixo de quantas pessoas já estão na lista. Atualmente: {filled_count(
            @event
          )}.
        </p>
      </section>

      <section class="rounded-card border border-hairline bg-base-100 p-4 shadow-card mb-3">
        <h2 class="text-[13px] font-extrabold mb-3">Senha (opcional)</h2>
        <p class="text-[11px] text-muted mb-3">
          Se preenchida, quem quiser ver o local ou entrar na lista precisa digitar
          a senha. Serve pra bloquear bots e curiosos — não precisa ser forte.
          Deixe em branco para remover.
        </p>

        <form
          phx-submit="save_password"
          phx-change="update_password_input"
          id="password-form"
          class="flex flex-wrap items-end gap-3"
        >
          <label class="flex-1 min-w-64">
            <span class="label text-sm mb-1">Senha</span>
            <input
              type="text"
              name="password"
              id="event-password-input"
              value={@password_input}
              placeholder="em branco = sem senha"
              class={[field_class(), "w-full font-mono"]}
              autocomplete="off"
            />
          </label>
          <button
            type="submit"
            class="rounded-row bg-ink px-4 py-2.5 text-xs font-bold text-ink-content transition-transform active:scale-[.97] disabled:opacity-40 disabled:pointer-events-none"
            disabled={@password_input == (@event.password || "")}
          >
            Salvar senha
          </button>
        </form>

        <p :if={@event.password} class="text-[11px] leading-relaxed text-muted mt-3">
          Senha atual:
          <code class="font-mono text-base-content bg-base-200 px-1 py-0.5 rounded">{@event.password}</code>
        </p>
      </section>

      <.link
        navigate={~p"/admin/r/#{@event.slug}/formulario"}
        class="mb-3 flex items-center gap-2.5 rounded-card border border-hairline bg-base-100 p-4 shadow-card"
      >
        <div class="min-w-0 flex-1">
          <div class="text-[13px] font-bold">Formulário de entrada</div>
          <div class="mt-0.5 text-[11px] text-muted">O que a pessoa preenche pra entrar</div>
        </div>
        <.icon name="tabler-chevron-right" class="size-4 shrink-0 text-ink/30" />
      </.link>

      <section class="rounded-card border border-hairline bg-base-100 p-4 shadow-card mb-3">
        <h2 class="text-[13px] font-extrabold mb-3">Status</h2>
        <!-- Current state lives in aria-checked rather than a conditional class,
             so the styling follows the attribute and a screen reader hears which
             one is selected. -->
        <div class="flex flex-wrap gap-1.5" role="radiogroup" aria-label="Status do rolê">
          <button
            :for={status <- [:active, :payments_only, :hidden, :done]}
            type="button"
            role="radio"
            aria-checked={to_string(@event.status == status)}
            phx-click="set_status"
            phx-value-status={to_string(status)}
            class={[
              "rounded-row bg-ink/[0.08] px-3.5 py-2.5 text-xs font-bold text-muted",
              "aria-checked:bg-ink aria-checked:text-ink-content",
              "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
            ]}
          >
            {status_label(status)}
          </button>
        </div>
        <p class="text-[11px] leading-relaxed text-muted mt-3">
          <strong>Ativo:</strong>
          aparece na página inicial e aceita novas inscrições. <strong>Só pagamentos:</strong>
          aparece na home, mas ninguém consegue entrar em novas listas —
          admin só marca quem pagou. <strong>Oculto:</strong>
          não aparece na home, só pelo link. <strong>Concluído:</strong>
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
          class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm bg-error text-error-content hover:bg-error/90 px-3 py-1.5"
        >
          Apagar rolezinho
        </button>
      </section>
    </Layouts.app>
    """
  end

  defp status_label(:active), do: "Ativo"
  defp status_label(:payments_only), do: "Só pagamentos"
  defp status_label(:hidden), do: "Oculto"
  defp status_label(:done), do: "Concluído"

  defp filled_count(%Event{main_list: list}) do
    Enum.count(list, fn a -> String.trim(a.name) != "" end)
  end
end

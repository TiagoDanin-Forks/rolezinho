defmodule RolezinhoWeb.EventLive do
  @moduledoc """
  Public event page. Renders the header/footer markdown and the two lists,
  and exposes actions for both anonymous visitors and the admin.
  """
  use RolezinhoWeb, :live_view

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee
  alias Rolezinho.Events

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    visibility = if socket.assigns.current_admin?, do: :any, else: :public

    case Events.find(slug, visibility: visibility) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Rolezinho não encontrado.")
         |> push_navigate(to: ~p"/")}

      event ->
        if connected?(socket), do: Events.subscribe(slug)

        {:ok,
         socket
         |> assign(:page_title, event.title)
         |> assign(:event, event)
         |> assign(:new_main_name, "")
         |> assign(:new_wait_name, "")
         |> assign(:editing_main, nil)
         |> assign(:editing_wait, nil)}
    end
  end

  # ---------- PubSub ----------

  @impl true
  def handle_info({:updated, %Event{} = event}, socket) do
    {:noreply, assign(socket, :event, event)}
  end

  def handle_info({:deleted, _event}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Este rolezinho foi apagado.")
     |> push_navigate(to: ~p"/")}
  end

  # ---------- Public actions ----------

  @impl true
  def handle_event("add_to_main", %{"name" => name}, socket) do
    case Events.add_to_main(socket.assigns.event, name) do
      {:ok, event} ->
        {:noreply,
         socket
         |> assign(:event, event)
         |> assign(:new_main_name, "")
         |> put_flash(:info, "Entrou na lista!")}

      {:error, :main_full} ->
        {:noreply, put_flash(socket, :error, "Lista principal cheia.")}

      {:error, :empty_name} ->
        {:noreply, put_flash(socket, :error, "Digite um nome.")}
    end
  end

  def handle_event("add_to_wait", %{"name" => name}, socket) do
    case Events.add_to_wait(socket.assigns.event, name) do
      {:ok, event} ->
        {:noreply,
         socket
         |> assign(:event, event)
         |> assign(:new_wait_name, "")
         |> put_flash(:info, "Entrou na reserva!")}

      {:error, :empty_name} ->
        {:noreply, put_flash(socket, :error, "Digite um nome.")}

      {:error, :wait_disabled} ->
        {:noreply, put_flash(socket, :error, "Este rolezinho não tem lista de reserva.")}
    end
  end

  def handle_event("promote", %{"index" => index}, socket) do
    case Events.promote(socket.assigns.event, String.to_integer(index)) do
      {:ok, event} ->
        {:noreply,
         socket
         |> assign(:event, event)
         |> put_flash(:info, "Promovido pra lista principal!")}

      {:error, :main_full} ->
        {:noreply, put_flash(socket, :error, "A lista principal está cheia.")}

      {:error, :not_found} ->
        {:noreply, socket}
    end
  end

  # ---------- Admin actions ----------

  def handle_event("toggle_paid_main", %{"index" => index}, socket) do
    require_admin!(socket)
    {:ok, event} = Events.toggle_paid_main(socket.assigns.event, String.to_integer(index))
    {:noreply, assign(socket, :event, event)}
  end

  def handle_event("toggle_paid_wait", %{"index" => index}, socket) do
    require_admin!(socket)
    {:ok, event} = Events.toggle_paid_wait(socket.assigns.event, String.to_integer(index))
    {:noreply, assign(socket, :event, event)}
  end

  def handle_event("remove_main", %{"index" => index}, socket) do
    require_admin!(socket)
    {:ok, event} = Events.remove_main(socket.assigns.event, String.to_integer(index))
    {:noreply, assign(socket, :event, event)}
  end

  def handle_event("remove_wait", %{"index" => index}, socket) do
    require_admin!(socket)
    {:ok, event} = Events.remove_wait(socket.assigns.event, String.to_integer(index))
    {:noreply, assign(socket, :event, event)}
  end

  def handle_event("start_edit_main", %{"index" => index}, socket) do
    require_admin!(socket)
    {:noreply, assign(socket, :editing_main, String.to_integer(index))}
  end

  def handle_event("start_edit_wait", %{"index" => index}, socket) do
    require_admin!(socket)
    {:noreply, assign(socket, :editing_wait, String.to_integer(index))}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, socket |> assign(:editing_main, nil) |> assign(:editing_wait, nil)}
  end

  def handle_event("rename_main", %{"index" => index, "name" => name}, socket) do
    require_admin!(socket)
    {:ok, event} = Events.rename_main(socket.assigns.event, String.to_integer(index), name)

    {:noreply,
     socket
     |> assign(:event, event)
     |> assign(:editing_main, nil)}
  end

  def handle_event("rename_wait", %{"index" => index, "name" => name}, socket) do
    require_admin!(socket)
    {:ok, event} = Events.rename_wait(socket.assigns.event, String.to_integer(index), name)

    {:noreply,
     socket
     |> assign(:event, event)
     |> assign(:editing_wait, nil)}
  end

  def handle_event("grow_main", _params, socket) do
    require_admin!(socket)
    new_size = socket.assigns.event.main_capacity + 1
    {:ok, event} = Events.resize_main(socket.assigns.event, new_size)
    {:noreply, assign(socket, :event, event)}
  end

  def handle_event("shrink_main", _params, socket) do
    require_admin!(socket)
    new_size = socket.assigns.event.main_capacity - 1
    {:ok, event} = Events.resize_main(socket.assigns.event, max(new_size, 1))
    {:noreply, assign(socket, :event, event)}
  end

  # ---------- Input tracking ----------

  def handle_event("update_new_main_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :new_main_name, name)}
  end

  def handle_event("update_new_wait_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :new_wait_name, name)}
  end

  defp require_admin!(socket) do
    unless socket.assigns.current_admin? do
      raise "unauthorized"
    end

    :ok
  end

  # ---------- Rendering ----------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_admin?={@current_admin?} page_title={@page_title}>
      <article class="space-y-8">
        <header class="space-y-3">
          <div class="flex items-center gap-2 text-xs text-base-content/50">
            <.link navigate={~p"/"} class="hover:text-base-content">← Rolezinhos</.link>
            <span>·</span>
            <span>/r/{@event.slug}</span>
            <span :if={@event.status == :hidden} class="badge badge-warning badge-sm">Oculto</span>
            <span :if={@event.status == :done} class="badge badge-neutral badge-sm">Concluído</span>
          </div>

          <h1 class="text-3xl sm:text-4xl font-bold tracking-tight">{@event.title}</h1>

          <div
            :if={@event.header != ""}
            class="prose prose-sm sm:prose-base max-w-none prose-p:my-2 leading-relaxed"
          >
            {raw(render_markdown(@event.header))}
          </div>
        </header>

        <div class="flex flex-wrap gap-2">
          <button
            id="copy-btn"
            type="button"
            phx-hook=".CopyEvent"
            data-text={Event.to_text(@event)}
            class="btn btn-sm btn-outline"
          >
            <.icon name="hero-clipboard" class="size-4" /> Copiar lista
          </button>
          <button
            id="share-btn"
            type="button"
            phx-hook=".ShareEvent"
            data-title={@event.title}
            data-text={Event.to_text(@event)}
            data-url={url_for(@event)}
            class="btn btn-sm btn-outline"
          >
            <.icon name="hero-share" class="size-4" /> Compartilhar
          </button>
          <a
            href={"/r/#{@event.slug}.txt"}
            target="_blank"
            rel="noopener"
            class="btn btn-sm btn-ghost"
          >
            <.icon name="hero-document-text" class="size-4" /> Texto puro
          </a>
          <.link
            :if={@current_admin?}
            navigate={~p"/admin/r/#{@event.slug}/edit"}
            class="btn btn-sm btn-primary"
          >
            <.icon name="hero-pencil-square" class="size-4" /> Editar
          </.link>
        </div>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-5">
          <div class="flex items-center justify-between mb-4 gap-3 flex-wrap">
            <div>
              <h2 class="text-xl font-semibold">Lista principal</h2>
              <p class="text-sm text-base-content/60">
                {filled_count(@event.main_list)} / {@event.main_capacity} vagas preenchidas
              </p>
            </div>
            <div :if={@current_admin?} class="join">
              <button
                type="button"
                phx-click="shrink_main"
                disabled={@event.main_capacity <= max(filled_count(@event.main_list), 1)}
                class="btn btn-sm join-item"
                title="Diminuir uma vaga"
              >
                <.icon name="hero-minus" class="size-4" />
              </button>
              <span class="btn btn-sm join-item pointer-events-none">Vagas: {@event.main_capacity}</span>
              <button
                type="button"
                phx-click="grow_main"
                class="btn btn-sm join-item"
                title="Adicionar uma vaga"
              >
                <.icon name="hero-plus" class="size-4" />
              </button>
            </div>
          </div>

          <ol class="space-y-2">
            <li
              :for={{%Attendee{} = att, i} <- Enum.with_index(@event.main_list, 1)}
              class={[
                "flex items-center gap-3 rounded-xl px-3 py-2 transition-colors",
                if(String.trim(att.name) == "",
                  do: "bg-base-200/50 border border-dashed border-base-300",
                  else: "bg-base-200"
                )
              ]}
            >
              <span class="text-sm font-mono w-8 text-right text-base-content/50">{i}.</span>

              <%= cond do %>
                <% @editing_main == i -> %>
                  <form
                    phx-submit="rename_main"
                    phx-value-index={i}
                    class="flex-1 flex items-center gap-2"
                  >
                    <input
                      type="text"
                      name="name"
                      value={att.name}
                      class="input input-sm flex-1"
                      autofocus
                    />
                    <button type="submit" class="btn btn-sm btn-primary">Salvar</button>
                    <button type="button" phx-click="cancel_edit" class="btn btn-sm btn-ghost">
                      Cancelar
                    </button>
                  </form>
                <% String.trim(att.name) == "" -> %>
                  <span class="flex-1 text-sm text-base-content/40 italic">vaga aberta</span>
                <% true -> %>
                  <span class="flex-1 truncate font-medium">
                    {att.name}
                    <span :if={att.paid} class="ml-1 text-success" title="Pago">✅</span>
                  </span>
              <% end %>

              <div class="flex items-center gap-1 shrink-0">
                <button
                  :if={@current_admin? and String.trim(att.name) != "" and @editing_main != i}
                  type="button"
                  phx-click="toggle_paid_main"
                  phx-value-index={i}
                  class={[
                    "btn btn-xs",
                    if(att.paid, do: "btn-success", else: "btn-outline")
                  ]}
                  title="Alternar pago"
                >
                  ✅
                </button>
                <button
                  :if={@current_admin? and String.trim(att.name) != "" and @editing_main != i}
                  type="button"
                  phx-click="start_edit_main"
                  phx-value-index={i}
                  class="btn btn-xs btn-ghost"
                  title="Editar nome"
                >
                  <.icon name="hero-pencil" class="size-3.5" />
                </button>
                <button
                  :if={@current_admin? and String.trim(att.name) != "" and @editing_main != i}
                  type="button"
                  phx-click="remove_main"
                  phx-value-index={i}
                  data-confirm="Remover essa pessoa?"
                  class="btn btn-xs btn-ghost text-error"
                  title="Remover"
                >
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
            </li>
          </ol>

          <div :if={not Event.main_full?(@event)} class="mt-4">
            <form
              phx-submit="add_to_main"
              phx-change="update_new_main_name"
              class="flex gap-2 flex-wrap"
              id="add-main-form"
            >
              <input
                type="text"
                name="name"
                value={@new_main_name}
                placeholder="Seu nome"
                class="input input-bordered flex-1 min-w-0"
                required
              />
              <button type="submit" class="btn btn-primary">Entrar na lista</button>
            </form>
          </div>

          <p
            :if={Event.main_full?(@event) and not @event.wait_enabled}
            class="mt-4 text-sm text-warning"
          >
            A lista principal está cheia.
          </p>
        </section>

        <section :if={@event.wait_enabled} class="rounded-2xl border border-base-300 bg-base-100 p-5">
          <div class="mb-4">
            <h2 class="text-xl font-semibold">Lista de reserva</h2>
            <p
              :if={@event.wait_intro not in ["Lista de reserva", ""]}
              class="text-sm text-base-content/60"
            >
              {@event.wait_intro}
            </p>
            <p class="text-sm text-base-content/60">
              {length(@event.wait_list)} pessoa(s) na reserva
            </p>
          </div>

          <ol :if={@event.wait_list != []} class="space-y-2">
            <li
              :for={{%Attendee{} = att, i} <- Enum.with_index(@event.wait_list, 1)}
              class="flex items-center gap-3 rounded-xl bg-base-200 px-3 py-2"
            >
              <span class="text-sm font-mono w-8 text-right text-base-content/50">{i}.</span>

              <%= cond do %>
                <% @editing_wait == i -> %>
                  <form
                    phx-submit="rename_wait"
                    phx-value-index={i}
                    class="flex-1 flex items-center gap-2"
                  >
                    <input
                      type="text"
                      name="name"
                      value={att.name}
                      class="input input-sm flex-1"
                      autofocus
                    />
                    <button type="submit" class="btn btn-sm btn-primary">Salvar</button>
                    <button type="button" phx-click="cancel_edit" class="btn btn-sm btn-ghost">Cancelar</button>
                  </form>
                <% true -> %>
                  <span class="flex-1 truncate font-medium">
                    {att.name}
                    <span :if={att.paid} class="ml-1 text-success" title="Pago">✅</span>
                  </span>
              <% end %>

              <div class="flex items-center gap-1 shrink-0">
                <button
                  :if={not Event.main_full?(@event) and @editing_wait != i}
                  type="button"
                  phx-click="promote"
                  phx-value-index={i}
                  class="btn btn-xs btn-primary"
                  title="Promover para a lista principal"
                >
                  <.icon name="hero-arrow-up" class="size-3.5" /> Promover
                </button>
                <button
                  :if={@current_admin? and @editing_wait != i}
                  type="button"
                  phx-click="toggle_paid_wait"
                  phx-value-index={i}
                  class={[
                    "btn btn-xs",
                    if(att.paid, do: "btn-success", else: "btn-outline")
                  ]}
                  title="Alternar pago"
                >
                  ✅
                </button>
                <button
                  :if={@current_admin? and @editing_wait != i}
                  type="button"
                  phx-click="start_edit_wait"
                  phx-value-index={i}
                  class="btn btn-xs btn-ghost"
                  title="Editar nome"
                >
                  <.icon name="hero-pencil" class="size-3.5" />
                </button>
                <button
                  :if={@current_admin? and @editing_wait != i}
                  type="button"
                  phx-click="remove_wait"
                  phx-value-index={i}
                  data-confirm="Remover da reserva?"
                  class="btn btn-xs btn-ghost text-error"
                  title="Remover"
                >
                  <.icon name="hero-x-mark" class="size-3.5" />
                </button>
              </div>
            </li>
          </ol>

          <div class="mt-4">
            <form
              phx-submit="add_to_wait"
              phx-change="update_new_wait_name"
              class="flex gap-2 flex-wrap"
              id="add-wait-form"
            >
              <input
                type="text"
                name="name"
                value={@new_wait_name}
                placeholder="Seu nome"
                class="input input-bordered flex-1 min-w-0"
                required
              />
              <button type="submit" class="btn btn-outline">Entrar na reserva</button>
            </form>
          </div>
        </section>

        <section :if={@event.footer != ""} class="rounded-2xl border border-base-300 bg-base-100 p-5">
          <div class="prose prose-sm sm:prose-base max-w-none">
            {raw(render_markdown(@event.footer))}
          </div>
        </section>
      </article>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyEvent">
        export default {
          mounted() {
            this.el.addEventListener("click", async () => {
              const text = this.el.dataset.text || ""
              try {
                await navigator.clipboard.writeText(text)
                this.flash("Copiado!")
              } catch (e) {
                // Fallback for very old browsers
                const ta = document.createElement("textarea")
                ta.value = text
                document.body.appendChild(ta)
                ta.select()
                try { document.execCommand("copy"); this.flash("Copiado!") } catch (_) { this.flash("Não deu pra copiar") }
                document.body.removeChild(ta)
              }
            })
          },
          flash(msg) {
            const original = this.el.innerHTML
            this.el.innerText = msg
            setTimeout(() => { this.el.innerHTML = original }, 1500)
          }
        }
      </script>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".ShareEvent">
        export default {
          mounted() {
            this.el.addEventListener("click", async () => {
              const title = this.el.dataset.title || "Rolezinho"
              const text = this.el.dataset.text || ""
              const url = this.el.dataset.url || location.href
              if (navigator.share) {
                try {
                  await navigator.share({ title, text, url })
                } catch (_) {}
              } else {
                try {
                  await navigator.clipboard.writeText(text + "\n" + url)
                  const original = this.el.innerHTML
                  this.el.innerText = "Link copiado!"
                  setTimeout(() => { this.el.innerHTML = original }, 1500)
                } catch (_) {}
              }
            })
          }
        }
      </script>
    </Layouts.app>
    """
  end

  defp filled_count(list), do: Enum.count(list, fn a -> String.trim(a.name) != "" end)

  defp url_for(%Event{slug: slug}) do
    RolezinhoWeb.Endpoint.url() <> "/r/" <> slug
  end

  defp render_markdown(text) when is_binary(text) do
    case Earmark.as_html(text, breaks: true, escape: true, compact_output: false) do
      {:ok, html, _warnings} -> html
      {:error, html, _warnings} -> html
    end
  end
end

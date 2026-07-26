defmodule RolezinhoWeb.FormConfigLive do
  @moduledoc """
  What the join form asks (spec 08).

  The default is a single field, and that is not laziness: every question sits
  between a person and the list, and the product's whole claim is that joining
  takes thirty seconds (RN-61). So adding one is a deliberate act by the
  organizer, framed here as a cost rather than a feature.

  The name cannot be removed or made optional (RN-60) — it is what a row
  displays, so a list without it would show nothing.
  """
  use RolezinhoWeb, :live_view

  alias Rolezinho.Event
  alias Rolezinho.Events

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Events.find(slug) do
      %Event{} = event ->
        {:ok,
         socket
         |> assign(:page_title, "Formulário · #{event.title}")
         |> assign(:new_label, "")
         |> assign(:new_type, "text")
         |> assign_event(event)}

      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Rolezinho não encontrado.")
         |> push_navigate(to: ~p"/admin")}
    end
  end

  defp assign_event(socket, %Event{} = event) do
    socket
    |> assign(:event, event)
    |> assign(:fields, Events.form_fields(event))
  end

  @impl true
  def handle_event("set_type", %{"value" => type}, socket) do
    {:noreply, assign(socket, :new_type, type)}
  end

  def handle_event("update_label", %{"label" => label}, socket) do
    {:noreply, assign(socket, :new_label, label)}
  end

  def handle_event("add_field", %{"label" => label}, socket) do
    params = %{"label" => label, "type" => socket.assigns.new_type}

    case Events.add_form_field(socket.assigns.event, params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> assign(:new_label, "")
         |> assign_event(event)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, message_for(reason))}
    end
  end

  def handle_event("toggle_required", %{"id" => id}, socket) do
    case Events.toggle_form_field_required(socket.assigns.event, id) do
      {:ok, event} -> {:noreply, assign_event(socket, event)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, message_for(reason))}
    end
  end

  def handle_event("remove_field", %{"id" => id}, socket) do
    case Events.remove_form_field(socket.assigns.event, id) do
      {:ok, event} -> {:noreply, assign_event(socket, event)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, message_for(reason))}
    end
  end

  defp message_for(:empty_label), do: "Dê um nome pro campo."
  defp message_for(:invalid_type), do: "Tipo de campo inválido."
  defp message_for(:too_many_fields), do: "Já são campos demais — o formulário vira pesquisa."
  defp message_for(:locked_field), do: "O nome não pode sair do formulário."
  defp message_for(:not_found), do: "Esse campo não existe mais."
  defp message_for(_), do: "Não deu pra salvar."

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_admin?={@current_admin?}
      page_title={@page_title}
      tabs?={false}
    >
      <div class="mx-auto max-w-[420px]">
        <header class="flex items-center gap-2">
          <.link
            navigate={~p"/admin/r/#{@event.slug}/edit"}
            class="grid size-11 shrink-0 place-items-center rounded-full bg-ink/[0.06] text-ink"
            aria-label="Voltar"
          >
            <.icon name="tabler-arrow-left" class="size-[18px]" />
          </.link>
          <div class="min-w-0">
            <h1 class="text-2xl font-extrabold tracking-tight">Formulário</h1>
            <p class="truncate text-[11px] text-ink/45">O que a pessoa preenche pra entrar</p>
          </div>
        </header>

        <section class="mt-5">
          <.section_header title="Campos" count={length(@fields)} />

          <div class="mt-2 space-y-2">
            <.field_config_row
              :for={field <- @fields}
              label={field.label}
              type={field.type}
              required={field.required}
              locked={field.locked}
              value={field.id}
              on_toggle_required="toggle_required"
              on_remove="remove_field"
            />
          </div>
        </section>

        <section class="mt-5 rounded-card border border-hairline bg-base-100 p-4 shadow-card">
          <h2 class="text-[13px] font-extrabold">Adicionar um campo</h2>
          <!-- RN-61: framed as a cost, because it is one. Every question is
               something between a person and the list. -->
          <p class="mt-0.5 text-[11px] leading-relaxed text-ink/45">
            Cada campo a mais é uma chance de alguém desistir no meio. Só peça o que
            você realmente vai usar.
          </p>

          <form phx-submit="add_field" phx-change="update_label" class="mt-3.5">
            <label class="block">
              <span class="mb-1 block text-[11px] font-bold text-ink/50">Pergunta</span>
              <input
                type="text"
                name="label"
                value={@new_label}
                maxlength="40"
                required
                placeholder="ex.: Camisa (P/M/G)"
                class="w-full rounded-row border border-ink/12 bg-base-100 px-3.5 py-3 text-[13px] font-semibold text-ink outline-none placeholder:font-normal placeholder:text-ink/35 focus:border-accent focus:ring-2 focus:ring-accent/20"
              />
            </label>

            <div class="mt-3">
              <span class="mb-1 block text-[11px] font-bold text-ink/50">Tipo de resposta</span>
              <.segmented_control
                name="Tipo de resposta"
                value={@new_type}
                options={[{"text", "Texto"}, {"tel", "Telefone"}, {"number", "Número"}]}
                change="set_type"
              />
            </div>

            <button
              type="submit"
              class="mt-3.5 w-full rounded-cta bg-ink px-4 py-3.5 text-[13px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97]"
            >
              Adicionar campo
            </button>
          </form>
        </section>

        <p class="mt-4 text-center text-[11px] leading-relaxed text-ink/45">
          As respostas ficam só neste rolê e só você vê — não aparecem na lista pública.
        </p>
      </div>
    </Layouts.app>
    """
  end
end

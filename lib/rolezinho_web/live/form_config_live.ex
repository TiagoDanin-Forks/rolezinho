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
  alias Rolezinho.Event.Policy
  alias Rolezinho.Events
  alias RolezinhoWeb.Plugs.Participant

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Events.find(slug) do
      %Event{} = event ->
        if Policy.can_edit?(event, policy_opts(socket, event)) do
          {:ok,
           socket
           |> assign(:page_title, "Formulário · #{event.title}")
           |> assign(:new_label, "")
           |> assign(:new_type, "text")
           |> assign(:editing_field_id, nil)
           |> assign_event(event)}
        else
          {:ok,
           socket
           |> put_flash(:error, "Você não pode editar o formulário desse rolê.")
           |> push_navigate(to: ~p"/r/#{event.slug}")}
        end

      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Rolezinho não encontrado.")
         |> push_navigate(to: ~p"/")}
    end
  end

  # Same shape `EventEditLive.policy_opts/2` builds — organizer via any
  # of the three paths (admin flag, held token, signed-in creator).
  defp policy_opts(socket, %Event{} = event) do
    [
      admin?: socket.assigns[:current_admin?] == true,
      organizer?:
        Participant.organizer?(
          %{"organizer_tokens" => socket.assigns[:organizer_tokens] || %{}},
          event
        ),
      participant_id: socket.assigns[:participant_id],
      current_user_id: socket.assigns[:current_user_id]
    ]
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
    require_can_edit!(socket)
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
    require_can_edit!(socket)

    case Events.toggle_form_field_required(socket.assigns.event, id) do
      {:ok, event} -> {:noreply, assign_event(socket, event)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, message_for(reason))}
    end
  end

  def handle_event("remove_field", %{"id" => id}, socket) do
    require_can_edit!(socket)

    case Events.remove_form_field(socket.assigns.event, id) do
      {:ok, event} -> {:noreply, assign_event(socket, event)}
      {:error, reason} -> {:noreply, put_flash(socket, :error, message_for(reason))}
    end
  end

  def handle_event("start_rename_field", %{"id" => id}, socket) do
    require_can_edit!(socket)
    # Guard: never enter edit mode for a locked field — the pencil is hidden
    # in the template for those already, but a fabricated event should not
    # be able to talk us into rendering an editable name row.
    fields = Events.form_fields(socket.assigns.event)

    case Enum.find(fields, &(&1.id == id)) do
      %{locked: false} -> {:noreply, assign(socket, :editing_field_id, id)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("cancel_rename_field", _params, socket) do
    {:noreply, assign(socket, :editing_field_id, nil)}
  end

  def handle_event("rename_field", %{"id" => id, "label" => label}, socket) do
    require_can_edit!(socket)

    case Events.rename_form_field(socket.assigns.event, id, label) do
      {:ok, event} ->
        {:noreply, socket |> assign(:editing_field_id, nil) |> assign_event(event)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, message_for(reason))}
    end
  end

  # Mirrors `EventEditLive.require_can_edit!/1`: template `:if` hides
  # the controls, this raises the fabricated-event case.
  defp require_can_edit!(socket) do
    unless Policy.can_edit?(socket.assigns.event, policy_opts(socket, socket.assigns.event)) do
      raise "unauthorized: not an editor of this event"
    end

    :ok
  end

  defp message_for(:empty_label), do: "Dê um nome pro campo."
  defp message_for(:label_too_long), do: "O nome do campo é muito longo."
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
            <p class="truncate text-[11px] text-muted">O que a pessoa preenche pra entrar</p>
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
              editing={@editing_field_id == field.id}
              value={field.id}
              on_toggle_required="toggle_required"
              on_remove="remove_field"
              on_start_rename="start_rename_field"
              on_rename="rename_field"
              on_cancel_rename="cancel_rename_field"
            />
          </div>
        </section>

        <section class="mt-5 rounded-card border border-hairline bg-base-100 p-4 shadow-card">
          <h2 class="text-[13px] font-extrabold">Adicionar um campo</h2>
          <!-- RN-61: framed as a cost, because it is one. Every question is
               something between a person and the list. -->
          <p class="mt-0.5 text-[11px] leading-relaxed text-muted">
            Cada campo a mais é uma chance de alguém desistir no meio. Só peça o que
            você realmente vai usar.
          </p>

          <form phx-submit="add_field" phx-change="update_label" class="mt-3.5">
            <label class="block">
              <span class="mb-1 block text-[11px] font-bold text-muted">Pergunta</span>
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
              <span class="mb-1 block text-[11px] font-bold text-muted">Tipo de resposta</span>
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

        <p class="mt-4 text-center text-[11px] leading-relaxed text-muted">
          As respostas ficam só neste rolê e só você vê — não aparecem na lista pública.
        </p>
      </div>
    </Layouts.app>
    """
  end
end

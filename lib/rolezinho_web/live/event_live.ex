defmodule RolezinhoWeb.EventLive do
  @moduledoc """
  Public event page. Renders the header/footer markdown and the two lists,
  and exposes actions for both anonymous visitors and the admin.
  """
  use RolezinhoWeb, :live_view

  alias Rolezinho.Event
  alias Rolezinho.Event.Attendee
  alias Rolezinho.Event.Cash
  alias Rolezinho.Event.Meta
  alias Rolezinho.Event.Policy
  alias Rolezinho.Events
  alias Rolezinho.Pix
  alias RolezinhoWeb.Components.UI.BottomSheet
  alias RolezinhoWeb.Plugs.Participant

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
         |> assign(:show_password_in_share?, false)
         |> assign_event(event)
         |> assign(:new_main_name, "")
         |> assign(:new_wait_name, "")
         |> assign(:editing_main, nil)
         |> assign(:editing_wait, nil)}
    end
  end

  defp assign_event(socket, %Event{} = event) do
    url = url_for(event)
    {meta, stripped_header} = Meta.extract(event.header)

    unlocked? =
      socket.assigns.current_admin? or
        not Event.password_protected?(event) or
        MapSet.member?(socket.assigns.unlocked_events, event.slug)

    # When the visitor hasn't unlocked, hide everything that could reveal
    # sensitive info: the location line, the free-form description block, the
    # PIX QR (which sits inside the description), and the calendar buttons.
    # The Quando (date/time) block on the widget still renders when set — it's
    # a common "save the date" preview.
    display_meta = if unlocked?, do: meta, else: %{meta | local: nil}
    display_header = if unlocked?, do: stripped_header, else: ""

    google_calendar_url =
      if unlocked?, do: Meta.google_url(display_meta, event.title, url), else: nil

    socket
    |> assign(:event, event)
    |> assign_identity(event, unlocked?)
    |> assign(:event_url, url)
    |> assign(:pix, if(unlocked?, do: Pix.detect(event.header), else: nil))
    |> assign(:meta, display_meta)
    |> assign(:stripped_header, display_header)
    |> assign(:google_calendar_url, google_calendar_url)
    |> assign(:unlocked?, unlocked?)
    |> assign(:signups_locked?, Event.locked_signups?(event))
    |> assign(:password_protected?, Event.password_protected?(event))
    |> assign(:has_location?, is_binary(meta.local) and meta.local != "")
    |> assign(:page_title, page_title_for(event))
    |> reset_share_toggle_if_disallowed()
    |> assign_shareable_text()
  end

  # Who this browser is *on this event*. The socket carries the session maps
  # (see RolezinhoWeb.Plugs.Participant), and both are scoped by slug so a claim
  # on one event never leaks into another.
  defp assign_identity(socket, %Event{} = event, unlocked?) do
    participant_id = Map.get(socket.assigns[:participants] || %{}, event.slug)

    organizer? =
      Participant.organizer?(
        %{"organizer_tokens" => socket.assigns[:organizer_tokens] || %{}},
        event
      )

    socket
    |> assign(:participant_id, participant_id)
    |> assign(:organizer?, organizer?)
    |> assign(:mine_index, own_row_index(event, participant_id))
    |> assign_cash(event, organizer?)
    |> assign_join_availability(event, participant_id, organizer?, unlocked?)
  end

  # Whether to offer the join action at all. Someone already on the list is not
  # offered it — the waiting list would take them a second time, and a list with
  # the same person twice is a list nobody trusts.
  defp assign_join_availability(socket, %Event{} = event, participant_id, organizer?, unlocked?) do
    opts = [
      admin?: socket.assigns.current_admin?,
      organizer?: organizer?,
      participant_id: participant_id
    ]

    can_join? =
      unlocked? and
        Policy.can_join?(event, opts) and
        is_nil(own_row_index(event, participant_id)) and
        is_nil(own_wait_index(event, participant_id)) and
        (not Event.main_full?(event) or event.wait_enabled)

    assign(socket, :can_join?, can_join?)
  end

  defp own_wait_index(%Event{wait_list: list}, participant_id) do
    case Enum.find_index(list, &Attendee.owned_by?(&1, participant_id)) do
      nil -> nil
      index -> index + 1
    end
  end

  # RN-15, without a screen of its own: the organizer is the one who ends up out
  # of pocket, so the outstanding total belongs on the page they already look at.
  # Nobody else sees it — what the group owes is the organizer's problem to
  # chase, not a scoreboard.
  defp assign_cash(socket, %Event{} = event, organizer?) do
    show? = (organizer? or socket.assigns.current_admin?) and Cash.outstanding?(event)

    socket
    |> assign(:cash, if(show?, do: Cash.summary(event)))
    |> assign(:reminder_text, if(show?, do: Cash.reminder_text(event)))
  end

  # The 1-based position of this browser's own row, or nil. Used to highlight it
  # and to decide which check is interactive — everyone else's is read-only.
  defp own_row_index(%Event{main_list: list}, participant_id) do
    case Enum.find_index(list, &Attendee.owned_by?(&1, participant_id)) do
      nil -> nil
      index -> index + 1
    end
  end

  # Mirrors Event.Policy for the template. The handler asks the policy again on
  # every action: this only decides what to draw, and drawing nothing is not a
  # gate.
  defp can_toggle?(_event, %Attendee{name: ""}, _mine?, _admin?, _organizer?), do: false
  defp can_toggle?(_event, _attendee, _mine?, true, _organizer?), do: true
  defp can_toggle?(_event, _attendee, _mine?, _admin?, true), do: true
  defp can_toggle?(_event, _attendee, mine?, _admin?, _organizer?), do: mine?

  defp can_remove?(%Attendee{name: ""}, _mine?, _admin?, _organizer?), do: false
  defp can_remove?(_attendee, _mine?, true, _organizer?), do: true
  defp can_remove?(_attendee, _mine?, _admin?, true), do: true
  defp can_remove?(_attendee, mine?, _admin?, _organizer?), do: mine?

  # RN-22: removal always confirms, naming who is being removed so a mistap in a
  # dense list is caught before it happens.
  defp remove_confirm(true, _name), do: "Sair da lista?"
  defp remove_confirm(false, name), do: "Remover #{name} da lista?"

  defp debt_summary(%{debtors: [_one], missing_cents: missing}) do
    "Falta #{Cash.format_amount(missing)} · 1 pessoa não pagou o Pix."
  end

  defp debt_summary(%{debtors: debtors, missing_cents: missing}) do
    "Faltam #{Cash.format_amount(missing)} · #{length(debtors)} pessoas não pagaram o Pix."
  end

  defp charge_label(%{debtors: [_one]}), do: "Cobrar no WhatsApp"
  defp charge_label(%{debtors: debtors}), do: "Cobrar os #{length(debtors)} no WhatsApp"

  # RN-03: a full main list does not hide the action, it changes what it means.
  # The label has to say which, or someone taps expecting a slot and lands in a
  # queue.
  defp join_label(%Event{} = event) do
    if Event.main_full?(event), do: "Entrar na espera", else: "Entrar na lista"
  end

  defp join_description(%Event{} = event) do
    if Event.main_full?(event) do
      "A lista principal está cheia. Você entra na espera e sobe se alguém sair."
    end
  end

  # Stamps the joining row with whatever identity this browser already holds for
  # the event. A visitor joining for the first time has none yet: a LiveView
  # cannot write to the session, so the id is issued by the join controller
  # (which does hold a conn) and only then travels back here.
  defp join_opts(socket) do
    case socket.assigns[:participant_id] do
      id when is_binary(id) and id != "" -> [participant_id: id]
      _ -> []
    end
  end

  # The options every Policy call needs. Kept in one place so a handler cannot
  # accidentally ask the policy a question with half the context missing.
  defp policy_opts(socket) do
    [
      admin?: socket.assigns.current_admin?,
      organizer?: socket.assigns[:organizer?] || false,
      participant_id: socket.assigns[:participant_id]
    ]
  end

  # If the event's password was removed or the user is no longer unlocked,
  # the toggle must snap back to `false` — both to keep the UI honest and to
  # prevent a stale flag from leaking the password on the next recompute.
  defp reset_share_toggle_if_disallowed(socket) do
    if socket.assigns.unlocked? and socket.assigns.password_protected? do
      socket
    else
      assign(socket, :show_password_in_share?, false)
    end
  end

  defp assign_shareable_text(socket) do
    %{
      event: event,
      event_url: url,
      unlocked?: unlocked?,
      show_password_in_share?: show_pw?
    } = socket.assigns

    include_password? =
      show_pw? and unlocked? and Event.password_protected?(event)

    text =
      Event.to_text(event, url,
        strip_location: not unlocked?,
        hide_description: not unlocked?,
        hide_names: not unlocked?,
        include_password: include_password?
      )

    assign(socket, :shareable_text, text)
  end

  # Page title patterns:
  #
  #   "Vôlei 7/18 (3 na reserva)"      - general case
  #   "Vôlei 7/18"                     - when the wait list is empty/disabled
  #   "Vôlei [Cheio] (5 na reserva)"   - when the main list is full
  #   "Vôlei [Cheio]"                  - full and no reserve
  defp page_title_for(%Event{} = event) do
    filled = filled_count(event.main_list)
    capacity = event.main_capacity

    status =
      if capacity > 0 and filled >= capacity do
        "[Cheio]"
      else
        "#{filled}/#{capacity}"
      end

    wait_count = length(event.wait_list)

    reserve =
      if event.wait_enabled and wait_count > 0 do
        " (#{wait_count} na reserva)"
      else
        ""
      end

    "#{event.title} #{status}#{reserve}"
  end

  # ---------- PubSub ----------

  @impl true
  def handle_info({:updated, %Event{} = event}, socket) do
    {:noreply, assign_event(socket, event)}
  end

  def handle_info({:deleted, _event}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Este rolezinho foi apagado.")
     |> push_navigate(to: ~p"/")}
  end

  def handle_info({:moved, %Event{} = event}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Este rolezinho mudou de endereço.")
     |> push_navigate(to: ~p"/r/#{event.slug}")}
  end

  # ---------- Public actions ----------

  @impl true
  def handle_event("add_to_main", %{"name" => name}, socket) do
    with :ok <- ensure_can_signup(socket),
         {:ok, event} <-
           Events.add_to_main(socket.assigns.event, name, join_opts(socket)) do
      {:noreply,
       socket
       |> assign_event(event)
       |> assign(:new_main_name, "")
       |> put_flash(:info, "Entrou na lista!")}
    else
      {:error, :locked} ->
        {:noreply, put_flash(socket, :error, "Precisa da senha pra entrar nesse rolezinho.")}

      {:error, :signups_locked} ->
        {:noreply,
         put_flash(socket, :error, "Este rolezinho está fechado para novas inscrições.")}

      {:error, :main_full} ->
        {:noreply, put_flash(socket, :error, "Lista principal cheia.")}

      {:error, :empty_name} ->
        {:noreply, put_flash(socket, :error, "Digite um nome.")}
    end
  end

  def handle_event("add_to_wait", %{"name" => name}, socket) do
    with :ok <- ensure_can_signup(socket),
         {:ok, event} <-
           Events.add_to_wait(socket.assigns.event, name, join_opts(socket)) do
      {:noreply,
       socket
       |> assign_event(event)
       |> assign(:new_wait_name, "")
       |> put_flash(:info, "Entrou na reserva!")}
    else
      {:error, :locked} ->
        {:noreply, put_flash(socket, :error, "Precisa da senha pra entrar nesse rolezinho.")}

      {:error, :signups_locked} ->
        {:noreply,
         put_flash(socket, :error, "Este rolezinho está fechado para novas inscrições.")}

      {:error, :empty_name} ->
        {:noreply, put_flash(socket, :error, "Digite um nome.")}

      {:error, :wait_disabled} ->
        {:noreply, put_flash(socket, :error, "Este rolezinho não tem lista de reserva.")}
    end
  end

  def handle_event("promote", %{"index" => index}, socket) do
    with :ok <- ensure_can_signup(socket),
         {:ok, event} <- Events.promote(socket.assigns.event, String.to_integer(index)) do
      {:noreply,
       socket
       |> assign_event(event)
       |> put_flash(:info, "Promovido pra lista principal!")}
    else
      {:error, :locked} ->
        {:noreply, put_flash(socket, :error, "Precisa da senha pra mexer nesse rolezinho.")}

      {:error, :signups_locked} ->
        {:noreply, put_flash(socket, :error, "Rolezinho fechado para novas inscrições.")}

      {:error, :main_full} ->
        {:noreply, put_flash(socket, :error, "A lista principal está cheia.")}

      {:error, :not_found} ->
        {:noreply, socket}
    end
  end

  # ---------- Admin actions ----------

  # RN-12/RN-13: the organizer marks anyone; a participant marks only their own
  # row. The check is here rather than in the template because the button being
  # absent does not stop the message from arriving.
  def handle_event("toggle_paid_main", %{"index" => index}, socket) do
    authorize_row(socket, :main, index, &Policy.can_toggle_paid?/3, fn event, position ->
      Events.toggle_paid_main(event, position)
    end)
  end

  def handle_event("toggle_paid_wait", %{"index" => index}, socket) do
    authorize_row(socket, :wait, index, &Policy.can_toggle_paid?/3, fn event, position ->
      Events.toggle_paid_wait(event, position)
    end)
  end

  # RN-21: a participant removes only themselves; the organizer removes anyone.
  def handle_event("remove_main", %{"index" => index}, socket) do
    authorize_row(socket, :main, index, &Policy.can_remove?/3, fn event, position ->
      Events.remove_main(event, position)
    end)
  end

  def handle_event("remove_wait", %{"index" => index}, socket) do
    authorize_row(socket, :wait, index, &Policy.can_remove?/3, fn event, position ->
      Events.remove_wait(event, position)
    end)
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
     |> assign_event(event)
     |> assign(:editing_main, nil)}
  end

  def handle_event("rename_wait", %{"index" => index, "name" => name}, socket) do
    require_admin!(socket)
    {:ok, event} = Events.rename_wait(socket.assigns.event, String.to_integer(index), name)

    {:noreply,
     socket
     |> assign_event(event)
     |> assign(:editing_wait, nil)}
  end

  def handle_event("grow_main", _params, socket) do
    require_admin!(socket)
    new_size = socket.assigns.event.main_capacity + 1
    {:ok, event} = Events.resize_main(socket.assigns.event, new_size)
    {:noreply, assign_event(socket, event)}
  end

  def handle_event("shrink_main", _params, socket) do
    require_admin!(socket)
    new_size = socket.assigns.event.main_capacity - 1
    {:ok, event} = Events.resize_main(socket.assigns.event, max(new_size, 1))
    {:noreply, assign_event(socket, event)}
  end

  def handle_event("clone", _params, socket) do
    require_admin!(socket)

    case Events.clone(socket.assigns.event) do
      {:ok, clone} ->
        {:noreply,
         socket
         |> put_flash(:info, "Rolezinho clonado. Ajuste e salve.")
         |> push_navigate(to: ~p"/admin/r/#{clone.slug}/edit")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Não deu pra clonar: #{inspect(reason)}")}
    end
  end

  # ---------- Share options ----------

  def handle_event("toggle_share_password", _params, socket) do
    if allowed_to_toggle_share_password?(socket) do
      show? = not socket.assigns.show_password_in_share?

      {:noreply,
       socket
       |> assign(:show_password_in_share?, show?)
       |> assign_shareable_text()}
    else
      # Silently drop unauthorized toggles so a crafted socket message can't
      # even leak that the flag exists on this session.
      {:noreply, socket}
    end
  end

  # ---------- Input tracking ----------

  def handle_event("update_new_main_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :new_main_name, name)}
  end

  def handle_event("update_new_wait_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :new_wait_name, name)}
  end

  # Ensures the current visitor may sign up: admins always can, otherwise the
  # slug must be in the unlocked-set (or the event must have no password).
  defp ensure_can_signup(socket) do
    if socket.assigns.unlocked?, do: :ok, else: {:error, :locked}
  end

  # Server-side gate for the "include password in share text" toggle. The
  # checkbox is only rendered for admins/unlocked users on password-protected
  # events, but we re-check here so a hacker crafting a raw socket message
  # can't flip the flag and read the password from `data-text`.
  defp allowed_to_toggle_share_password?(socket) do
    socket.assigns.unlocked? and Event.password_protected?(socket.assigns.event)
  end

  defp require_admin!(socket) do
    unless socket.assigns.current_admin? do
      raise "unauthorized"
    end

    :ok
  end

  # Resolves a row from a client-supplied index, asks the policy whether this
  # caller may act on it, and only then runs the operation.
  #
  # The index arrives over the socket, so it is hostile input twice over: it can
  # point outside the list, and it can point at somebody else's row. Both are
  # rejected here — silently, because a caller that fabricated the message is not
  # owed an explanation, and a stale index from a list that changed underneath is
  # not worth an error toast.
  defp authorize_row(socket, list, raw_index, allowed?, operation) do
    event = socket.assigns.event

    with {:ok, position} <- parse_position(raw_index),
         %Attendee{} = attendee <- fetch_row(event, list, position),
         true <- allowed?.(event, attendee, policy_opts(socket)),
         {:ok, updated} <- operation.(event, position) do
      {:noreply, assign_event(socket, updated)}
    else
      _ -> {:noreply, socket}
    end
  end

  defp parse_position(index) when is_integer(index), do: {:ok, index}

  defp parse_position(index) when is_binary(index) do
    case Integer.parse(index) do
      {position, ""} when position > 0 -> {:ok, position}
      _ -> :error
    end
  end

  defp parse_position(_), do: :error

  # Positions are 1-based, and a row only exists if someone is in it: an empty
  # slot has nothing to pay for and nobody to remove.
  defp fetch_row(%Event{} = event, list, position) do
    case event |> list_for(list) |> Enum.at(position - 1) do
      %Attendee{name: name} = attendee when name != "" -> attendee
      _ -> nil
    end
  end

  defp list_for(%Event{main_list: list}, :main), do: list
  defp list_for(%Event{wait_list: list}, :wait), do: list

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
            <span
              :if={@event.status == :hidden}
              class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-warning/15 text-warning"
            >Oculto</span>
            <span
              :if={@event.status == :done}
              class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-base-300 text-base-content"
            >Concluído</span>
            <span
              :if={@signups_locked?}
              class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-info/15 text-info"
            >Só pagamentos</span>
            <span
              :if={@password_protected?}
              class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium border border-base-300"
            >Com senha</span>
          </div>

          <h1 class="text-3xl sm:text-4xl font-bold tracking-tight">{@event.title}</h1>

          <.payments_only_notice :if={@signups_locked?} />

          <div :if={@cash} class="mt-4">
            <.alert_banner tone="warn">{debt_summary(@cash)}</.alert_banner>
            <a
              :if={@reminder_text}
              href={"https://wa.me/?text=" <> URI.encode(@reminder_text)}
              target="_blank"
              rel="noopener"
              class="mt-2 flex w-full items-center justify-center gap-1.5 rounded-cta bg-ink px-4 py-3 text-[13px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
            >
              <.icon name="tabler-brand-whatsapp" class="size-4" />
              {charge_label(@cash)}
            </a>
          </div>

          <.unlock_panel
            :if={@password_protected? and not @unlocked?}
            slug={@event.slug}
            has_location?={@has_location?}
          />

          <%= cond do %>
            <% Meta.any?(@meta) and @pix -> %>
              <div class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4 items-stretch">
                <.when_where_panel
                  meta={@meta}
                  slug={@event.slug}
                  google_calendar_url={@google_calendar_url}
                />
                <.pix_panel pix={@pix} full_width />
              </div>

              <div
                :if={@stripped_header != ""}
                class="prose prose-sm sm:prose-base max-w-none prose-p:my-2 leading-relaxed"
              >
                {raw(render_markdown(@stripped_header))}
              </div>
            <% Meta.any?(@meta) -> %>
              <.when_where_panel
                meta={@meta}
                slug={@event.slug}
                google_calendar_url={@google_calendar_url}
              />

              <div
                :if={@stripped_header != ""}
                class="prose prose-sm sm:prose-base max-w-none prose-p:my-2 leading-relaxed"
              >
                {raw(render_markdown(@stripped_header))}
              </div>
            <% @pix -> %>
              <div class="grid sm:grid-cols-[minmax(0,1fr)_auto] gap-6 items-start">
                <div
                  :if={@stripped_header != ""}
                  class="prose prose-sm sm:prose-base max-w-none prose-p:my-2 leading-relaxed"
                >
                  {raw(render_markdown(@stripped_header))}
                </div>
                <.pix_panel pix={@pix} />
              </div>
            <% true -> %>
              <div
                :if={@stripped_header != ""}
                class="prose prose-sm sm:prose-base max-w-none prose-p:my-2 leading-relaxed"
              >
                {raw(render_markdown(@stripped_header))}
              </div>
          <% end %>
        </header>

        <div class="flex items-center gap-1.5">
          <button
            type="button"
            phx-click={BottomSheet.show("share-sheet")}
            class="grid size-11 place-items-center rounded-full bg-ink/[0.06] text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
            aria-label="Compartilhar a lista"
          >
            <.icon name="tabler-share" class="size-[18px]" />
          </button>
          <.link
            :if={@current_admin?}
            navigate={~p"/admin/r/#{@event.slug}/edit"}
            class="grid size-11 place-items-center rounded-full bg-ink/[0.06] text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
            aria-label="Editar o rolê"
          >
            <.icon name="tabler-pencil" class="size-[18px]" />
          </.link>
          <button
            :if={@current_admin?}
            type="button"
            phx-click="clone"
            data-confirm="Criar uma cópia deste rolezinho?"
            class="grid size-11 place-items-center rounded-full bg-ink/[0.06] text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
            aria-label="Clonar o rolê"
          >
            <.icon name="tabler-copy" class="size-[18px]" />
          </button>
        </div>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-5">
          <div class="flex items-center justify-between mb-4 gap-3 flex-wrap">
            <div>
              <h2 class="text-xl font-semibold">Lista principal</h2>
              <p class="text-sm text-base-content/60">
                {filled_count(@event.main_list)} / {@event.main_capacity} vagas preenchidas
              </p>
            </div>
            <div :if={@current_admin?} class="inline-flex -space-x-px">
              <button
                type="button"
                phx-click="shrink_main"
                disabled={@event.main_capacity <= max(filled_count(@event.main_list), 1)}
                class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 rounded-none first:rounded-l-md last:rounded-r-md"
                title="Diminuir uma vaga"
              >
                <.icon name="tabler-minus" class="size-4" />
              </button>
              <span class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 rounded-none first:rounded-l-md last:rounded-r-md pointer-events-none">Vagas: {@event.main_capacity}</span>
              <button
                type="button"
                phx-click="grow_main"
                class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 rounded-none first:rounded-l-md last:rounded-r-md"
                title="Adicionar uma vaga"
              >
                <.icon name="tabler-plus" class="size-4" />
              </button>
            </div>
          </div>

          <!-- RN-14: a check on its own does not say whether it means paid or
               confirmed, so the legend is not optional. -->
          <.payment_legend
            :if={@unlocked?}
            paid_label="já pagou o Pix"
            unpaid_label="ainda não pagou"
            class="mb-2"
          />

          <.coachmark :if={@mine_index} seen_key="paid-check" class="mb-2">
            Toque no check quando fizer o Pix. Só você marca o seu.
          </.coachmark>

          <ol class="overflow-hidden rounded-row border border-hairline bg-base-100">
            <li :for={{%Attendee{} = att, i} <- Enum.with_index(@event.main_list, 1)}>
              <%= if @editing_main == i do %>
                <form
                  phx-submit="rename_main"
                  phx-value-index={i}
                  class="flex items-center gap-2 border-b border-ink/6 px-3.5 py-2.5"
                >
                  <input
                    type="text"
                    name="name"
                    value={att.name}
                    class={[field_class(), "flex-1"]}
                    autofocus
                  />
                  <button
                    type="submit"
                    class="shrink-0 rounded-lg bg-ink px-2.5 py-1.5 text-[11px] font-bold text-ink-content"
                  >
                    Salvar
                  </button>
                  <button
                    type="button"
                    phx-click="cancel_edit"
                    class="shrink-0 px-2 py-1.5 text-[11px] font-bold text-ink/55"
                  >
                    Cancelar
                  </button>
                </form>
              <% else %>
                <.participant_row
                  number={i}
                  name={display_name(att.name, @unlocked?)}
                  paid={att.paid}
                  highlighted={@mine_index == i}
                  divider={i < length(@event.main_list)}
                  paid_click={
                    can_toggle?(@event, att, @mine_index == i, @current_admin?, @organizer?) &&
                      "toggle_paid_main"
                  }
                  join_click={
                    @unlocked? and not @signups_locked? and
                      JS.focus(to: "#add-main-form input[name=name]")
                  }
                  empty_label="Vaga livre"
                  join_label="Entrar"
                  phx-value-index={i}
                >
                  <:actions>
                    <button
                      :if={@current_admin? and String.trim(att.name) != ""}
                      type="button"
                      phx-click="start_edit_main"
                      phx-value-index={i}
                      class="grid size-11 shrink-0 place-items-center text-ink/35"
                      aria-label={"Editar #{att.name}"}
                    >
                      <.icon name="tabler-pencil" class="size-4" />
                    </button>
                    <button
                      :if={can_remove?(att, @mine_index == i, @current_admin?, @organizer?)}
                      type="button"
                      phx-click="remove_main"
                      phx-value-index={i}
                      data-confirm={remove_confirm(@mine_index == i, att.name)}
                      class="grid size-11 shrink-0 place-items-center text-ink/35"
                      aria-label={
                        if @mine_index == i, do: "Sair da lista", else: "Remover #{att.name}"
                      }
                    >
                      <.icon name="tabler-x" class="size-4" />
                    </button>
                  </:actions>
                </.participant_row>
              <% end %>
            </li>
          </ol>

          <p
            :if={not @unlocked? and not @signups_locked?}
            class="mt-4 text-sm text-base-content/60"
          >
            Digite a senha acima pra entrar na lista.
          </p>

          <p :if={@signups_locked?} class="mt-4 text-sm text-base-content/60">
            Novas inscrições estão pausadas. Marcados com <span class="text-success">✅</span> pagaram.
          </p>

          <p
            :if={Event.main_full?(@event) and not @event.wait_enabled and not @signups_locked?}
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
                      class={[field_class(), "px-2 py-1 flex-1"]}
                      autofocus
                    />
                    <button
                      type="submit"
                      class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 bg-primary text-primary-content hover:bg-primary/90"
                    >Salvar</button>
                    <button
                      type="button"
                      phx-click="cancel_edit"
                      class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 hover:bg-base-200"
                    >Cancelar</button>
                  </form>
                <% true -> %>
                  <span class={[
                    "flex-1 truncate font-medium",
                    not @unlocked? && "tracking-widest text-base-content/60"
                  ]}>
                    {display_name(att.name, @unlocked?)}
                    <span :if={att.paid} class="ml-1 text-success" title="Pago">✅</span>
                  </span>
              <% end %>

              <div class="flex items-center gap-1 shrink-0">
                <button
                  :if={not Event.main_full?(@event) and @editing_wait != i}
                  type="button"
                  phx-click="promote"
                  phx-value-index={i}
                  class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-2 py-1 text-xs bg-primary text-primary-content hover:bg-primary/90"
                  title="Promover para a lista principal"
                >
                  <.icon name="tabler-arrow-up" class="size-3.5" /> Promover
                </button>
                <button
                  :if={@current_admin? and @editing_wait != i}
                  type="button"
                  phx-click="toggle_paid_wait"
                  phx-value-index={i}
                  class={[
                    "inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-2 py-1 text-xs",
                    if(att.paid,
                      do: "bg-success text-success-content hover:bg-success/90",
                      else: "border border-base-300 hover:bg-base-200"
                    )
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
                  class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-2 py-1 text-xs hover:bg-base-200"
                  title="Editar nome"
                >
                  <.icon name="tabler-pencil" class="size-3.5" />
                </button>
                <button
                  :if={@current_admin? and @editing_wait != i}
                  type="button"
                  phx-click="remove_wait"
                  phx-value-index={i}
                  data-confirm="Remover da reserva?"
                  class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-2 py-1 text-xs hover:bg-base-200 text-error"
                  title="Remover"
                >
                  <.icon name="tabler-x" class="size-3.5" />
                </button>
              </div>
            </li>
          </ol>

          <div :if={@unlocked? and not @signups_locked?} class="mt-4">
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
                class={[field_class(), "flex-1 min-w-0"]}
                required
              />
              <button
                type="submit"
                class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm border border-base-300 hover:bg-base-200"
              >Entrar na reserva</button>
            </form>
          </div>

          <p
            :if={not @unlocked? and not @signups_locked?}
            class="mt-4 text-sm text-base-content/60"
          >
            Digite a senha acima pra entrar na reserva.
          </p>
        </section>

        <section :if={@event.footer != ""} class="rounded-2xl border border-base-300 bg-base-100 p-5">
          <div class="prose prose-sm sm:prose-base max-w-none">
            {raw(render_markdown(@event.footer))}
          </div>
        </section>
      </article>

      <!-- One primary action per screen, at the bottom where the thumb is.
           The label follows what tapping it will actually do: with the main
           list full, joining means joining the queue (RN-03). -->
      <div :if={@can_join?} class="sticky bottom-0 -mx-5 mt-6 bg-canvas px-5 pb-2 pt-3">
        <button
          type="button"
          phx-click={BottomSheet.show("join-sheet")}
          class="w-full rounded-cta bg-ink px-4 py-4 text-[15px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        >
          {join_label(@event)}
        </button>
      </div>

      <!-- RN-40: the group chat is the channel, so the product's job is to hand
           back a block of text somebody can paste there. The preview shows what
           will actually be pasted, because a share button that copies something
           unseen gets pasted once and never again. -->
      <.bottom_sheet id="share-sheet" title="Mandar no grupo">
        <label
          :if={@password_protected? and @unlocked?}
          class="mb-3 flex items-center gap-2.5 rounded-row bg-tint px-3 py-2.5"
        >
          <input
            id="share-password-toggle"
            type="checkbox"
            class={checkbox_class()}
            phx-click="toggle_share_password"
            checked={@show_password_in_share?}
          />
          <span class="text-xs font-semibold">Incluir a senha no texto</span>
        </label>

        <.share_preview text={@shareable_text} />

        <:actions>
          <button
            id="copy-btn"
            type="button"
            phx-hook=".CopyText"
            data-text={@shareable_text}
            data-copied-label="Copiado!"
            class="flex-1 rounded-row bg-ink/[0.06] py-3 text-xs font-bold text-ink"
          >
            Copiar
          </button>
          <button
            id="share-btn"
            type="button"
            phx-hook=".ShareEvent"
            data-title={@event.title}
            data-text={@shareable_text}
            data-url={@event_url}
            class="flex-1 rounded-row bg-ink py-3 text-xs font-bold text-ink-content"
          >
            Compartilhar
          </button>
        </:actions>
      </.bottom_sheet>

      <!-- Rendered only when joining is actually allowed. A sheet that exists
           but is hidden is markup someone can still submit, and the gate has to
           be the server's decision rather than a CSS class. -->
      <.bottom_sheet
        :if={@can_join?}
        id="join-sheet"
        title={join_label(@event)}
        description={join_description(@event)}
      >
        <form
          id="join-form"
          method="post"
          action={~p"/r/#{@event.slug}/join"}
          phx-hook=".JoinDefaults"
        >
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
          <input
            type="hidden"
            name="list"
            value={if Event.main_full?(@event), do: "wait", else: "main"}
          />

          <label class="block">
            <span class="mb-1 block text-[11px] font-bold text-ink/50">Seu nome *</span>
            <input
              type="text"
              name="name"
              data-profile="name"
              required
              maxlength="60"
              autocomplete="name"
              placeholder="Como te chamam no grupo"
              class="w-full rounded-row border border-ink/12 bg-base-100 px-3.5 py-3 text-[13px] font-semibold text-ink outline-none placeholder:font-normal placeholder:text-ink/35 focus:border-accent focus:ring-2 focus:ring-accent/20"
            />
          </label>

          <button
            type="submit"
            class="mt-3.5 w-full rounded-cta bg-ink px-4 py-4 text-[15px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97]"
          >
            {join_label(@event)}
          </button>
        </form>

        <script :type={Phoenix.LiveView.ColocatedHook} name=".JoinDefaults">
          export default {
            mounted() {
              // Someone who has filled in their name once should not type it
              // again in every list they join.
              let profile = {}
              try { profile = JSON.parse(localStorage.getItem("rolezinho:profile") || "{}") } catch (_) {}

              this.el.querySelectorAll("[data-profile]").forEach((input) => {
                if (!input.value) input.value = profile[input.dataset.profile] || ""
              })
            }
          }
        </script>
      </.bottom_sheet>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyText">
        export default {
          mounted() {
            this.el.addEventListener("click", async () => {
              const text = this.el.dataset.text || ""
              const done = this.el.dataset.copiedLabel || "Copiado!"
              try {
                await navigator.clipboard.writeText(text)
                this.flash(done)
              } catch (e) {
                // Fallback for very old browsers
                const ta = document.createElement("textarea")
                ta.value = text
                document.body.appendChild(ta)
                ta.select()
                try { document.execCommand("copy"); this.flash(done) } catch (_) { this.flash("Não deu pra copiar") }
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

  # Attendee name shown in the list rows. Password-protected events hide names
  # from visitors who haven't unlocked the session yet.
  defp display_name(name, true = _unlocked?), do: name
  defp display_name("", _), do: ""
  defp display_name(_name, false = _unlocked?), do: Event.hidden_name_placeholder()

  defp url_for(%Event{slug: slug}) do
    RolezinhoWeb.Endpoint.url() <> "/r/" <> slug
  end

  # ---------- Payments-only banner + unlock panel ----------

  defp payments_only_notice(assigns) do
    ~H"""
    <section class="rounded-2xl border border-info/40 bg-info/10 p-4 sm:p-5">
      <div class="flex items-start gap-3">
        <.icon name="tabler-cash-banknote" class="size-5 text-info shrink-0 mt-0.5" />
        <div class="space-y-1">
          <p class="font-semibold">Rolezinho fechado, só pagamentos.</p>
          <p class="text-sm text-base-content/80">
            Quem ainda não tem o <span class="text-success font-semibold">✅</span>
            precisa pagar pra confirmar a vaga. Não dá pra entrar em novas listas
            enquanto o rolezinho estiver nesse estado.
          </p>
        </div>
      </div>
    </section>
    """
  end

  attr :slug, :string, required: true
  attr :has_location?, :boolean, required: true

  # The gate someone lands on when a shared link reaches them (RN-41). It is a
  # whole screen rather than a warning strip because it is the only thing to do
  # here: everything else on the page is deliberately withheld until the password
  # is right, on the server.
  defp unlock_panel(assigns) do
    ~H"""
    <section class="mx-auto max-w-[420px] px-2 py-6 text-center">
      <div class="mx-auto grid size-16 place-items-center rounded-[22px] bg-ink">
        <.icon name="tabler-lock" class="size-7 text-accent" />
      </div>

      <p class="mt-5 text-[11px] font-bold uppercase tracking-wide text-accent">
        Convite recebido
      </p>
      <h2 class="mt-2 text-2xl font-extrabold leading-tight tracking-tight">
        Essa lista é<br />protegida por senha
      </h2>
      <p class="mt-3 text-sm leading-relaxed text-ink/55">
        <%= if @has_location? do %>
          Digite a senha que veio junto com o link pra ver o local, os nomes e entrar na lista.
        <% else %>
          Digite a senha que veio junto com o link pra ver os nomes e entrar na lista.
        <% end %>
      </p>

      <form
        method="post"
        action={~p"/r/#{@slug}/unlock"}
        id={"unlock-form-" <> @slug}
        class="mt-6 rounded-[20px] border border-hairline bg-base-100 p-4 text-left shadow-card"
      >
        <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
        <label class="block">
          <span class="text-[11px] font-bold uppercase tracking-wide text-ink/50">
            Senha da lista
          </span>
          <input
            type="password"
            name="password"
            placeholder="ex: VOLEI25"
            autocomplete="off"
            autocapitalize="characters"
            required
            class="mt-2 w-full border-0 border-b-2 border-ink/12 bg-transparent px-0 py-1.5 text-xl font-extrabold uppercase tracking-[2px] text-ink outline-none placeholder:tracking-normal placeholder:text-ink/25 focus:border-accent"
          />
        </label>

        <button
          type="submit"
          class="mt-4 w-full rounded-cta bg-ink px-4 py-4 text-[15px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        >
          Ver o rolê
        </button>
      </form>

      <p class="mt-3.5 text-xs text-ink/45">
        Não tem a senha? Pede pra quem te chamou.
      </p>
    </section>
    """
  end

  # ---------- When/Where widget ----------

  attr :meta, :map, required: true
  attr :slug, :string, required: true
  attr :google_calendar_url, :string, required: true, doc: "nil when no date is set"

  defp when_where_panel(assigns) do
    ~H"""
    <section class="rounded-2xl border border-primary/20 bg-primary/5 p-4 sm:p-5 space-y-3 lg:col-span-2">
      <div :if={@meta.date || @meta.time} class="flex items-start gap-3">
        <.icon name="tabler-calendar" class="size-5 text-primary shrink-0 mt-0.5" />
        <div class="min-w-0">
          <p class="font-semibold">Quando</p>
          <p class="text-base-content/80">{Meta.format_when(@meta)}</p>
        </div>
      </div>

      <div :if={@meta.local} class="flex items-start gap-3">
        <.icon name="tabler-map-pin" class="size-5 text-primary shrink-0 mt-0.5" />
        <div class="min-w-0">
          <p class="font-semibold">Onde</p>
          <p class="text-base-content/80 break-words">{@meta.local}</p>
        </div>
      </div>

      <div :if={@google_calendar_url} class="flex flex-wrap gap-2 pt-1">
        <a
          href={@google_calendar_url}
          target="_blank"
          rel="noopener"
          class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 bg-primary text-primary-content hover:bg-primary/90"
        >
          <.icon name="tabler-calendar-event" class="size-4" /> Google Calendar
        </a>
        <a
          href={"/r/" <> @slug <> "/calendar.ics"}
          class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-3 py-1.5 border border-base-300 hover:bg-base-200"
          download
        >
          <.icon name="tabler-download" class="size-4" /> Apple / .ics
        </a>
      </div>
    </section>
    """
  end

  # ---------- PIX panel ----------

  attr :pix, :map, required: true
  attr :full_width, :boolean, default: false

  defp pix_panel(assigns) do
    assigns = assign(assigns, :svg, Rolezinho.Pix.qr_svg(assigns.pix.key, width: 180))

    ~H"""
    <aside class={[
      "flex flex-col items-center gap-2 rounded-2xl border border-base-300 bg-base-100 p-3",
      if(@full_width, do: "w-full h-full justify-center", else: "shrink-0 sm:w-52")
    ]}>
      <div class="bg-white rounded-lg p-2 w-full flex items-center justify-center">
        {raw(@svg)}
      </div>
      <div class="flex items-center gap-2">
        <p class="text-sm font-mono tabular-nums text-center break-all">{@pix.display}</p>
        <button
          type="button"
          id={"copy-pix-" <> String.replace(@pix.raw, ~r/\D/, "")}
          phx-hook=".CopyText"
          data-text={@pix.raw}
          data-copied-label="Copiado!"
          class="inline-flex items-center justify-center gap-1.5 rounded-md font-medium transition-colors cursor-pointer disabled:opacity-50 disabled:pointer-events-none px-4 py-2 text-sm px-2 py-1 text-xs border border-base-300 hover:bg-base-200"
          title="Copiar chave Pix"
        >
          <.icon name="tabler-clipboard" class="size-3.5" /> Copiar
        </button>
      </div>
    </aside>
    """
  end

  defp render_markdown(text) when is_binary(text) do
    text
    |> neutralize_attribute_injection()
    |> Earmark.as_html(breaks: true, escape: true, compact_output: false)
    |> case do
      {:ok, html, _warnings} -> html
      {:error, html, _warnings} -> html
    end
  end

  # Earmark 1.4.x interpolates link/image URLs and titles into `href`/`src`/`title`
  # attributes without escaping double quotes, so `[x](http://a/?b=c" onerror="alert(1))`
  # closes the attribute and injects an event handler (EEF-CVE-2026-48591, no patched
  # release — the package is retired). `escape: true` does not cover this: it escapes
  # markup in text, not quotes inside generated attributes.
  #
  # Writes here are anonymous, so this is reachable by any visitor. Replacing the quote
  # with its HTML entity before parsing means whatever reaches an attribute can no longer
  # terminate it, while the character still renders as a quote in body text. Markdown
  # itself goes away in the structured-fields migration, which removes this path entirely.
  defp neutralize_attribute_injection(text), do: String.replace(text, "\"", "&quot;")
end

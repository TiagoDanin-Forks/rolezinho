defmodule RolezinhoWeb.UpdateFromChatLive do
  @moduledoc """
  Bulk-update surface for events, driven by a query string an LLM built
  (see `/atualizar.md`).

  Two states:

    * **picker** — no `event` (or unknown `event`) was supplied. Shows
      the caller's updatable events (`Events.list_updatable_for/2`,
      admin-widened) so they can pick one. Each picker row is a link
      that reuses the current query string plus `event=<slug>`.

    * **diff** — `event=<slug>` resolves to something the caller is
      allowed to update (`Policy.can_edit?/2`). Renders two columns:
      *Antes* (read-only current state) on the left, *Depois*
      (editable proposal) on the right. Every input on the right side
      starts prefilled from the URL, then merged with the event's
      current state so untouched slots preserve what's there. A
      "Confirmar" button applies via `Events.apply_chat_update/2`.

  New form-field suggestions live above the diff as dismissible chips
  \u2014 one per key the URL used that isn't in the event yet. Confirming
  the update creates every chip that's still there; discarding one
  strips that key from every proposed row's `values`.

  Everything on the right side is HTML-controlled — no LiveView form
  bindings on the individual inputs. On submit we read the form via
  the standard `form.data` in `handle_event/3` and hand it to
  `Events.apply_chat_update/2`. This is deliberate: an LLM-generated
  URL can have dozens of rows, and re-rendering the whole form on
  every keystroke would be noisy. The user's edits stay in the DOM
  until they click Confirmar.
  """
  use RolezinhoWeb, :live_view

  alias Rolezinho.Event
  alias Rolezinho.Event.FormField
  alias Rolezinho.Event.Policy
  alias Rolezinho.Events
  alias Rolezinho.Events.ChatUpdate
  alias RolezinhoWeb.Plugs.Participant

  @impl true
  def mount(params, _session, socket) do
    if socket.assigns.current_user do
      chat_update = ChatUpdate.parse(params)

      socket =
        socket
        |> assign(:page_title, "Atualizar rolezinho")
        |> assign(:raw_params, params)
        |> assign(:chat_update, chat_update)
        |> assign(:discarded_field_keys, MapSet.new())
        |> assign(:error_message, nil)

      case load_event(chat_update.event_slug) do
        %Event{} = event ->
          if Policy.can_edit?(event, policy_opts(socket, event)) do
            {:ok, load_diff(socket, event, chat_update)}
          else
            # Editable listing is filtered server-side; a `?event=`
            # for something we don't own falls back to the picker so
            # the caller can pick from what they actually control.
            {:ok, load_picker(socket)}
          end

        nil ->
          {:ok, load_picker(socket)}
      end
    else
      # Anonymous visitors get bounced to sign in and brought back
      # with the whole query string preserved, so a click on the
      # LLM's link doesn't lose the parsed proposal on the way through
      # auth.
      return_to = current_full_path(params)
      {:ok, push_navigate(socket, to: ~p"/entrar?#{[return_to: return_to]}")}
    end
  end

  # `params` on mount is the nested map Plug decoded (`names[0]=X`
  # becomes `%{"names" => %{"0" => "X"}}`). `Plug.Conn.Query.encode/1`
  # is the inverse and preserves the `key[subkey]=` shape — plain
  # `URI.encode_query/1` cannot handle nested maps and would raise
  # on any LLM-shaped input.
  defp current_full_path(params) when is_map(params) do
    query = Plug.Conn.Query.encode(params)
    "/atualizar" <> if(query == "", do: "", else: "?" <> query)
  end

  defp load_event(nil), do: nil
  defp load_event(slug) when is_binary(slug), do: Events.find(slug, visibility: :any)

  defp load_picker(socket) do
    admin? = socket.assigns[:current_admin?] == true
    user_id = socket.assigns[:current_user_id]

    socket
    |> assign(:mode, :picker)
    |> assign(:events, Events.list_updatable_for(user_id, admin?: admin?))
    |> assign(:event, nil)
  end

  defp load_diff(socket, %Event{} = event, %ChatUpdate{} = chat_update) do
    non_locked_fields = Enum.reject(Events.form_fields(event), & &1.locked)
    existing_field_ids = MapSet.new(non_locked_fields, & &1.id)

    # Every key the URL used, categorized: `known` land into the
    # event's existing fields (rendered as normal inputs); `new` show
    # up as "criar campo" chips above the diff.
    {known, new} =
      Enum.split_with(chat_update.field_keys, &MapSet.member?(existing_field_ids, &1))

    # Rebuild each proposal so the values map's keys are the
    # normalized field ids (they already are, from parse/1) and so
    # discarded-field values are stripped before render.
    proposed_rows = build_proposed_rows(event, chat_update.main_rows, MapSet.new())
    proposed_wait = build_proposed_rows_for(event.wait_list, chat_update.wait_rows, MapSet.new())

    # Capacity the human is about to confirm: explicit URL value
    # wins; otherwise honor the largest URL slot index; otherwise the
    # current capacity. Always clamped to at least the current capacity
    # on load so we don't accidentally present "shrink" as the default
    # when the LLM only mentioned a subset of the list.
    max_slot_from_url =
      chat_update.main_rows
      |> Enum.map(& &1.index)
      |> Enum.max(fn -> -1 end)
      |> Kernel.+(1)

    proposed_capacity =
      chat_update.main_capacity ||
        max(event.main_capacity, max_slot_from_url)

    socket
    |> assign(:mode, :diff)
    |> assign(:event, event)
    |> assign(:non_locked_fields, non_locked_fields)
    |> assign(:known_field_keys, known)
    |> assign(:new_field_keys, new)
    |> assign(:proposed_main, proposed_rows)
    |> assign(:proposed_wait, proposed_wait)
    |> assign(:proposed_capacity, proposed_capacity)
    |> assign(:field_labels, chat_update.field_labels)
  end

  # For each main-list slot 1..capacity, build a %{index, current,
  # proposed} triple so the template can iterate once and render both
  # columns side by side. Also renders "phantom" rows past current
  # capacity for URL slot indices that don't have a row yet — those
  # correspond to LLM-requested list growth and get created when the
  # human confirms with a matching `capacity` bump.
  defp build_proposed_rows(%Event{main_list: main_list}, url_rows, discarded) do
    max_url_index = url_rows |> Enum.map(& &1.index) |> Enum.max(fn -> -1 end)
    padded = pad_with_phantoms(main_list, max_url_index + 1)
    build_proposed_rows_for(padded, url_rows, discarded)
  end

  defp build_proposed_rows_for(list, url_rows, discarded) do
    url_by_index = Map.new(url_rows, fn %ChatUpdate.Row{index: i} = row -> {i, row} end)

    list
    |> Enum.with_index()
    |> Enum.map(fn {attendee, i} ->
      row = Map.get(url_by_index, i)
      proposed = merge_current_with_url(attendee, row, discarded)

      %{
        index: i,
        current: attendee,
        proposed: proposed,
        changed?: row_changed?(attendee, proposed),
        # A phantom slot is one that doesn't exist on the event yet;
        # `changed?` is decided against an empty attendee, so this
        # flag is what the template uses to render the "nova vaga"
        # affordance instead of a plain empty slot.
        phantom?:
          attendee.__struct__ == Rolezinho.Event.Attendee and
            attendee == %Rolezinho.Event.Attendee{} and
            i >= length(list_without_phantoms(list, i))
      }
    end)
  end

  # Small helper used only in `phantom?` — fine to always evaluate to
  # the padded list for the moment, since the diff column doesn't need
  # to distinguish empty-real from empty-phantom for correctness (the
  # "nova vaga" label is nice-to-have polish, not required for the
  # confirm loop). Kept explicit rather than inlined so we can teach
  # phantom rendering later without touching row-building code.
  defp list_without_phantoms(list, _i), do: list

  defp pad_with_phantoms(list, target_length) when length(list) >= target_length, do: list

  defp pad_with_phantoms(list, target_length) do
    list ++ List.duplicate(%Rolezinho.Event.Attendee{}, target_length - length(list))
  end

  # Merge current attendee state with the URL's suggestion into the
  # data structure the *Depois* column renders from.
  defp merge_current_with_url(%Rolezinho.Event.Attendee{} = attendee, nil, _discarded) do
    %{
      name: attendee.name,
      values: attendee.values || %{},
      paid: attendee.paid
    }
  end

  defp merge_current_with_url(attendee, %ChatUpdate.Row{} = row, discarded) do
    name = if is_nil(row.name), do: attendee.name, else: row.name

    values =
      (attendee.values || %{})
      |> Map.merge(row.values || %{})
      |> Map.drop(MapSet.to_list(discarded))

    paid =
      case row.paid do
        nil -> attendee.paid
        value -> value
      end

    %{name: name, values: values, paid: paid}
  end

  defp row_changed?(%Rolezinho.Event.Attendee{} = current, proposed) do
    String.trim(current.name || "") != String.trim(proposed.name || "") or
      (current.values || %{}) != proposed.values or
      current.paid != proposed.paid
  end

  # ---------- Event handlers ----------

  @impl true
  def handle_event("discard_field", %{"key" => key}, socket) do
    discarded = MapSet.put(socket.assigns.discarded_field_keys, key)

    # Rebuild the *proposed* view with the discarded keys stripped so
    # the human sees the effect immediately, before confirming.
    new_field_keys =
      socket.assigns.new_field_keys
      |> Enum.reject(&(&1 == key))

    proposed_main =
      build_proposed_rows(
        socket.assigns.event,
        socket.assigns.chat_update.main_rows,
        discarded
      )

    {:noreply,
     socket
     |> assign(:discarded_field_keys, discarded)
     |> assign(:new_field_keys, new_field_keys)
     |> assign(:proposed_main, proposed_main)}
  end

  # Undo a discard: put the key back into the "new field" chip row.
  # Handy when the human clicked descartar and then changed their mind.
  def handle_event("keep_field", %{"key" => key}, socket) do
    discarded = MapSet.delete(socket.assigns.discarded_field_keys, key)

    new_field_keys =
      socket.assigns.chat_update.field_keys
      |> Enum.filter(fn k ->
        k not in Enum.map(socket.assigns.non_locked_fields, & &1.id) and
          not MapSet.member?(discarded, k)
      end)

    proposed_main =
      build_proposed_rows(
        socket.assigns.event,
        socket.assigns.chat_update.main_rows,
        discarded
      )

    {:noreply,
     socket
     |> assign(:discarded_field_keys, discarded)
     |> assign(:new_field_keys, new_field_keys)
     |> assign(:proposed_main, proposed_main)}
  end

  # The Confirmar submit. Reads the form's `rows[<i>][name|paid|values]`
  # tree straight out of `params`, hands it to `Events.apply_chat_update/2`.
  def handle_event("confirm", params, socket) do
    event = socket.assigns.event

    unless event && Policy.can_edit?(event, policy_opts(socket, event)) do
      raise "unauthorized"
    end

    add_fields =
      socket.assigns.new_field_keys
      |> Enum.map(fn key ->
        # LLM-supplied label wins when present; otherwise recover a
        # friendly human label by title-casing the dash-split slug.
        # The former keeps the original casing ("Nome na camisa"),
        # the latter falls back to something readable ("Nome Na
        # Camisa") when the LLM didn't send the hint.
        label =
          case Map.get(socket.assigns.field_labels || %{}, key) do
            label when is_binary(label) and label != "" -> label
            _ -> humanize_key(key)
          end

        %{"label" => label}
      end)

    main_changes = parse_form_rows(Map.get(params, "main", %{}))
    wait_changes = parse_form_rows(Map.get(params, "wait", %{}))

    # Capacity the human confirmed via the header input; falls back
    # to the proposal we computed at load time if the input wasn't
    # touched (or wasn't sent, which is what happens on the tests
    # that just submit the form).
    target_capacity =
      case Map.get(params, "capacity") do
        value when is_binary(value) ->
          case Integer.parse(value) do
            {n, _} when n > 0 -> n
            _ -> socket.assigns.proposed_capacity
          end

        _ ->
          socket.assigns.proposed_capacity
      end

    changes = %{
      add_fields: add_fields,
      remove_field_ids: [],
      main: main_changes,
      wait: wait_changes,
      main_capacity: target_capacity
    }

    case Events.apply_chat_update(event, changes) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Lista atualizada.")
         |> push_navigate(to: ~p"/r/#{updated.slug}")}

      {:error, reason} ->
        {:noreply, assign(socket, :error_message, format_error(reason))}
    end
  end

  # Turns `%{"1" => %{"name" => "..", "paid" => "on", "values" => %{...}}}`
  # into the 1-based integer-keyed map `apply_chat_update/2` wants.
  defp parse_form_rows(nil), do: %{}

  defp parse_form_rows(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, row_params}, acc ->
      case Integer.parse(to_string(k)) do
        {i, ""} when i >= 1 and is_map(row_params) ->
          Map.put(acc, i, %{
            "name" => Map.get(row_params, "name"),
            "values" => Map.get(row_params, "values", %{}),
            "paid" => Map.get(row_params, "paid") in ["on", "true", "1", true]
          })

        _ ->
          acc
      end
    end)
  end

  defp format_error({:add_field, %{"label" => label}, reason}),
    do: "Não deu pra criar o campo #{label}: #{inspect(reason)}."

  defp format_error(other), do: "Não deu pra salvar: #{inspect(other)}."

  # Mirrors `EventEditLive.policy_opts/2` so the two "can this person
  # edit this event" surfaces answer the same way.
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

  # ---------- Render ----------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_admin?={@current_admin?}
      current_user={@current_user}
      page_title={@page_title}
    >
      <div class="mx-auto max-w-5xl px-2 py-6">
        <header class="mb-6">
          <h1 class="text-2xl font-extrabold tracking-tight">Atualizar rolezinho</h1>
          <p class="mt-1 text-[13px] leading-relaxed text-muted">
            Colou um link vindo do WhatsApp? Escolhe o rolê (se pedirmos), confere as
            mudanças no lado direito e confirma. A tela mostra o que vai ficar diferente
            antes de gravar.
          </p>
          <p class="mt-2 text-[11px] leading-snug text-muted">
            Doc do formato de link (pra IAs) em <code>/atualizar.md</code>.
          </p>
        </header>

        <.picker :if={@mode == :picker} events={@events} raw_params={@raw_params} />

        <.diff
          :if={@mode == :diff}
          event={@event}
          proposed_main={@proposed_main}
          proposed_wait={@proposed_wait}
          proposed_capacity={@proposed_capacity}
          non_locked_fields={@non_locked_fields}
          new_field_keys={@new_field_keys}
          discarded_field_keys={@discarded_field_keys}
          field_labels={@field_labels}
          error_message={@error_message}
        />
      </div>
    </Layouts.app>
    """
  end

  # ---------- Picker ----------

  attr :events, :list, required: true
  attr :raw_params, :map, required: true

  defp picker(assigns) do
    ~H"""
    <div :if={@events == []} class="rounded-card border border-hairline bg-base-100 p-6 text-center">
      <p class="text-[13px] font-semibold text-ink">Você não tem rolês em aberto pra atualizar.</p>
      <p class="mt-2 text-[11px] leading-snug text-muted">
        Criar um rolê fica em <.link navigate={~p"/criar"} class="underline">/criar</.link>. Aqui
        listamos só os que estão <strong>ativos</strong> ou <strong>averiguando resenha</strong>.
      </p>
    </div>

    <ul :if={@events != []} class="space-y-2">
      <li :for={event <- @events}>
        <.link
          patch={picker_url(event, @raw_params)}
          class="flex items-center justify-between gap-3 rounded-card border border-hairline bg-base-100 p-4 shadow-card transition-colors hover:border-accent"
        >
          <div class="min-w-0 flex-1">
            <p class="truncate text-[14px] font-bold text-ink">{event.title}</p>
            <p class="mt-0.5 text-[11px] text-muted">
              /r/{event.slug} · atualizado {relative_time(event.updated_at)}
            </p>
          </div>
          <.icon name="tabler-arrow-right" class="size-4 shrink-0 text-muted" />
        </.link>
      </li>
    </ul>
    """
  end

  # Preserves every LLM-supplied param when the human picks an event.
  # `Plug.Conn.Query.encode/1` handles the nested `names[0]=` shape;
  # `URI.encode_query/1` doesn't and would raise here.
  defp picker_url(%Event{slug: slug}, raw_params) do
    params = Map.put(raw_params || %{}, "event", slug)
    "/atualizar?" <> Plug.Conn.Query.encode(params)
  end

  defp relative_time(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "agora"
      diff < 3600 -> "há #{div(diff, 60)} min"
      diff < 86_400 -> "há #{div(diff, 3600)} h"
      true -> "há #{div(diff, 86_400)} d"
    end
  end

  defp relative_time(_), do: ""

  # ---------- Diff ----------

  attr :event, Event, required: true
  attr :proposed_main, :list, required: true
  attr :proposed_wait, :list, required: true
  attr :proposed_capacity, :integer, required: true
  attr :non_locked_fields, :list, required: true
  attr :new_field_keys, :list, required: true
  attr :discarded_field_keys, MapSet, required: true
  attr :field_labels, :map, default: %{}
  attr :error_message, :string, required: true

  defp diff(assigns) do
    ~H"""
    <div class="mb-4 rounded-card border border-hairline bg-base-100 p-4 shadow-card">
      <p class="text-[11px] font-bold uppercase tracking-wide text-muted">Editando</p>
      <p class="mt-1 text-[15px] font-bold text-ink">{@event.title}</p>
      <p class="mt-0.5 text-[11px] text-muted">/r/{@event.slug}</p>
    </div>

    <.new_field_chips
      :if={@new_field_keys != []}
      keys={@new_field_keys}
      field_labels={@field_labels}
    />

    <form id="confirm-form" phx-submit="confirm" class="space-y-6">
      <section>
        <div class="mb-3 flex items-end justify-between gap-3">
          <h2 class="text-[12px] font-extrabold uppercase tracking-wide text-muted">
            Lista principal
          </h2>

          <!--
            Label is deliberately "Vagas" (slots) rather than "Tamanho"
            (size) so it never collides with a custom field called
            `tamanho` — that would leave the discard-field UX indexable
            by a substring that also appears in a header the human
            can't discard.
          -->
          <label class="flex items-center gap-2">
            <span class="text-[11px] font-bold text-muted">Vagas</span>
            <input
              type="number"
              name="capacity"
              min="1"
              max="99"
              value={@proposed_capacity}
              class="w-16 rounded-row border border-ink/12 bg-base-100 px-2 py-1 text-center text-[13px] font-bold text-ink outline-none focus:border-accent focus:ring-2 focus:ring-accent/20"
            />
            <span
              :if={@proposed_capacity != @event.main_capacity}
              class="rounded-full bg-accent/15 px-1.5 py-[1px] text-[10px] font-bold text-accent"
            >
              antes: {@event.main_capacity}
            </span>
          </label>
        </div>

        <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
          <div>
            <p class="mb-2 text-[11px] font-bold text-muted">Antes</p>
            <.antes_column rows={@proposed_main} fields={@non_locked_fields} />
          </div>

          <div>
            <p class="mb-2 text-[11px] font-bold text-muted">Depois</p>
            <.depois_column
              rows={@proposed_main}
              fields={@non_locked_fields}
              new_field_keys={@new_field_keys}
              field_labels={@field_labels}
              scope="main"
            />
          </div>
        </div>
      </section>

      <section :if={any_row_present?(@proposed_wait)}>
        <h2 class="mb-2 text-[12px] font-extrabold uppercase tracking-wide text-muted">
          Lista de espera
        </h2>

        <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
          <div>
            <p class="mb-2 text-[11px] font-bold text-muted">Antes</p>
            <!--
              Wait rows share the same event-wide field definitions
              as main rows now (2026-09 addition); the visual layout
              is otherwise the same as the main list.
            -->
            <.antes_column rows={@proposed_wait} fields={@non_locked_fields} />
          </div>

          <div>
            <p class="mb-2 text-[11px] font-bold text-muted">Depois</p>
            <.depois_column
              rows={@proposed_wait}
              fields={@non_locked_fields}
              new_field_keys={@new_field_keys}
              field_labels={@field_labels}
              scope="wait"
            />
          </div>
        </div>
      </section>

      <p :if={@error_message} class="text-[13px] font-bold text-error">{@error_message}</p>

      <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <p class="text-[11px] text-muted">
          Nada é gravado até você clicar em <strong>Confirmar</strong>.
        </p>
        <button
          type="submit"
          class="inline-flex items-center justify-center gap-2 rounded-cta bg-ink px-4 py-3 text-[13px] font-bold text-ink-content shadow-cta transition-transform active:scale-[.97]"
        >
          <.icon name="tabler-check" class="size-4" /> Confirmar atualização
        </button>
      </div>
    </form>
    """
  end

  attr :keys, :list, required: true
  attr :field_labels, :map, default: %{}

  defp new_field_chips(assigns) do
    ~H"""
    <div class="mb-4 rounded-card border border-hairline bg-accent/10 p-3">
      <p class="text-[11px] font-bold text-ink">
        Campos novos sugeridos pelo link
      </p>
      <p class="mt-0.5 text-[11px] leading-snug text-muted">
        Vão ser criados no rolê ao confirmar. Descarta os que você não quer.
      </p>

      <div class="mt-2 flex flex-wrap gap-2">
        <div
          :for={key <- @keys}
          class="inline-flex items-center gap-1.5 rounded-row bg-base-100 px-2.5 py-1 text-[11px] font-bold text-ink shadow-sm"
        >
          {display_label(key, @field_labels)}
          <button
            type="button"
            phx-click="discard_field"
            phx-value-key={key}
            class="grid size-5 place-items-center rounded-full text-muted hover:bg-ink/10 hover:text-ink"
            aria-label={"Descartar campo #{key}"}
          >
            <.icon name="tabler-x" class="size-3" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Prefer the LLM-supplied label (kept in the URL as
  # `field_labels[<key>]=<Human Label>`) so the chip and the created
  # field carry the original casing. Falls back to the humanized
  # slug when no label hint was sent.
  defp display_label(key, labels) when is_map(labels) do
    case Map.get(labels, key) do
      value when is_binary(value) and value != "" -> value
      _ -> humanize_key(key)
    end
  end

  defp display_label(key, _), do: humanize_key(key)

  defp humanize_key(key) when is_binary(key) do
    key |> String.split("-") |> Enum.map_join(" ", &String.capitalize/1)
  end

  attr :rows, :list, required: true
  attr :fields, :list, required: true

  defp antes_column(assigns) do
    ~H"""
    <ol class="space-y-1.5">
      <li
        :for={row <- @rows}
        class={[
          "rounded-row border p-2.5",
          row.changed? && "border-warning/40 bg-warning/5",
          not row.changed? && "border-hairline bg-base-100"
        ]}
      >
        <div class="flex items-baseline gap-2">
          <span class="text-[11px] font-mono text-muted">{row.index + 1}.</span>
          <span :if={String.trim(row.current.name) == ""} class="text-[12px] text-muted italic">
            (vago)
          </span>
          <span
            :if={String.trim(row.current.name) != ""}
            class="text-[13px] font-semibold text-ink"
          >
            {row.current.name}
          </span>
          <span
            :if={row.current.paid}
            class="ml-auto rounded-full bg-accent/15 px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide text-accent"
          >
            pago
          </span>
        </div>

        <dl
          :if={@fields != [] and row.current.values not in [nil, %{}]}
          class="mt-1 space-y-0.5 text-[11px] text-muted"
        >
          <div :for={field <- @fields}>
            <span :if={value = value_for(row.current, field)}>
              <dt class="inline font-bold">{field.label}:</dt>
              {value}
            </span>
          </div>
        </dl>
      </li>
    </ol>
    """
  end

  attr :rows, :list, required: true
  attr :fields, :list, required: true
  attr :new_field_keys, :list, required: true
  attr :field_labels, :map, default: %{}
  attr :scope, :string, required: true

  defp depois_column(assigns) do
    ~H"""
    <ol class="space-y-1.5">
      <li
        :for={row <- @rows}
        class={[
          "rounded-row border p-2.5",
          row.changed? && "border-accent/60 bg-accent/5",
          not row.changed? && "border-hairline bg-base-100"
        ]}
      >
        <div class="flex items-baseline gap-2">
          <span class="text-[11px] font-mono text-muted">{row.index + 1}.</span>
          <input
            type="text"
            name={"#{@scope}[#{row.index + 1}][name]"}
            value={row.proposed.name}
            maxlength="60"
            placeholder="(vago)"
            class="flex-1 rounded-row border border-ink/12 bg-base-100 px-2.5 py-1.5 text-[13px] font-semibold text-ink outline-none placeholder:font-normal placeholder:italic placeholder:text-ink/35 focus:border-accent focus:ring-2 focus:ring-accent/20"
          />

          <label class="ml-auto inline-flex items-center gap-1.5 rounded-full bg-ink/[0.04] px-2 py-0.5 text-[11px] font-bold text-muted">
            <input
              type="checkbox"
              name={"#{@scope}[#{row.index + 1}][paid]"}
              value="on"
              checked={row.proposed.paid}
              class="size-3.5 rounded border-ink/25 text-accent focus:ring-accent/40"
            /> pago
          </label>
        </div>

        <div :if={@fields != [] or @new_field_keys != []} class="mt-2 space-y-1.5">
          <label :for={field <- @fields} class="block">
            <span class="mb-0.5 block text-[10px] font-bold uppercase tracking-wide text-muted">
              {field.label}
            </span>
            <input
              type="text"
              name={"#{@scope}[#{row.index + 1}][values][#{field.id}]"}
              value={Map.get(row.proposed.values || %{}, field.id, "")}
              maxlength="200"
              class="w-full rounded-row border border-ink/12 bg-base-100 px-2.5 py-1 text-[12px] text-ink outline-none focus:border-accent focus:ring-2 focus:ring-accent/20"
            />
          </label>

          <!--
            Inputs for the still-pending "new field" suggestions. The
            event doesn't have these fields yet, but confirming the
            update creates them (see `add_fields` in the confirm
            handler), so the values need to be in the submitted form.
            Rendered with a small "novo" badge so the human knows this
            input will only stick if they leave the corresponding chip
            in place at the top of the page.
          -->
          <label :for={key <- @new_field_keys} class="block">
            <span class="mb-0.5 flex items-center gap-1.5 text-[10px] font-bold uppercase tracking-wide text-muted">
              {display_label(key, @field_labels)}
              <span class="rounded-full bg-accent/15 px-1.5 py-[1px] text-[9px] font-bold text-accent">
                novo
              </span>
            </span>
            <input
              type="text"
              name={"#{@scope}[#{row.index + 1}][values][#{key}]"}
              value={Map.get(row.proposed.values || %{}, key, "")}
              maxlength="200"
              class="w-full rounded-row border border-ink/12 bg-base-100 px-2.5 py-1 text-[12px] text-ink outline-none focus:border-accent focus:ring-2 focus:ring-accent/20"
            />
          </label>
        </div>
      </li>
    </ol>
    """
  end

  defp any_row_present?(rows) do
    Enum.any?(rows, fn row ->
      String.trim(row.current.name || "") != "" or String.trim(row.proposed.name || "") != ""
    end)
  end

  defp value_for(%{values: values}, %FormField{id: id}) when is_map(values) do
    case Map.get(values, id) do
      value when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end

  defp value_for(_row, _field), do: nil
end

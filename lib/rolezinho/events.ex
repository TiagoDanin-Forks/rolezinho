defmodule Rolezinho.Events do
  @moduledoc """
  Context for managing rolezinhos, backed by Postgres.

  Every persisting function broadcasts on the `event:<slug>` PubSub topic so
  connected LiveViews stay in sync, plus a `events:home` topic for the home
  page listing.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Phoenix.PubSub
  alias Rolezinho.Event
  alias Rolezinho.Event.FormField
  alias Rolezinho.Event.Meta
  alias Rolezinho.Event.Parser
  alias Rolezinho.Event.Token
  alias Rolezinho.Repo

  @pubsub Rolezinho.PubSub

  @statuses [:active, :payments_only, :hidden, :done]

  @doc "PubSub topic for a specific slug."
  def topic(slug), do: "event:" <> slug

  @doc "Subscribes the caller to updates for a given slug."
  def subscribe(slug), do: PubSub.subscribe(@pubsub, topic(slug))

  @doc "Subscribes the caller to the home-page updates."
  def subscribe_home, do: PubSub.subscribe(@pubsub, "events:home")

  # ---------- Listing ----------

  @doc """
  Lists events shown on the public home page (active + payments_only).

  Ordered by when they happen, not by name: someone opening the home screen
  wants to know what is next, and alphabetical order puts tomorrow's event
  below one three weeks away. Events with no date sort last — they cannot be
  next if nobody has said when.
  """
  def list_open do
    from(e in Event,
      where: e.status in ^Event.open_statuses(),
      order_by: [asc_nulls_last: e.starts_at, asc: e.title]
    )
    |> Repo.all()
  end

  @doc "Lists strictly active events."
  def list_active, do: do_list(:active)

  @doc "Lists payments-only events."
  def list_payments_only, do: do_list(:payments_only)

  @doc "Lists hidden events."
  def list_hidden, do: do_list(:hidden)

  @doc "Lists done events."
  def list_done, do: do_list(:done)

  defp do_list(status) do
    from(e in Event, where: e.status == ^status, order_by: [asc: e.title])
    |> Repo.all()
  end

  # ---------- Fetching ----------

  @doc """
  Finds an event by slug. Returns nil if not found.

    * `visibility: :public` -> active + hidden (default: excludes :done)
    * `visibility: :any`    -> any status
    * `visibility: :active` -> only active
  """
  def find(slug, opts \\ []) when is_binary(slug) do
    visibility = Keyword.get(opts, :visibility, :any)

    statuses =
      case visibility do
        :public -> Event.public_statuses()
        :any -> @statuses
        :active -> [:active]
      end

    from(e in Event, where: e.slug == ^slug and e.status in ^statuses)
    |> Repo.one()
  end

  @doc """
  Finds the event a given organizer token administers.

  Returns `nil` for a blank token so that a browser sending no secret never
  resolves to an event.
  """
  @spec get_by_organizer_token(String.t() | nil) :: Event.t() | nil
  def get_by_organizer_token(token) when is_binary(token) and token != "" do
    Repo.get_by(Event, organizer_token: token)
  end

  def get_by_organizer_token(_), do: nil

  @doc "Returns true when a slug already exists in any status."
  def slug_taken?(slug) do
    from(e in Event, where: e.slug == ^slug, select: 1)
    |> Repo.exists?()
  end

  # ---------- Creation ----------

  @doc """
  Creates a new event from admin form params.

  Expected keys (strings): `title`, `slug`, `description`, `local`, `date`,
  `time`, `main_size`, `wait_size`.
  """
  def create(params, opts \\ []) when is_map(params) do
    with {:ok, attrs} <- validate_create_params(params) do
      changeset =
        %Event{}
        |> Event.changeset(build_attrs(attrs, initial_status(opts)))
        # Set here rather than cast from params: accepting it as input would let
        # a visitor choose the secret that administers the event.
        |> Ecto.Changeset.put_change(:organizer_token, Token.generate_organizer())

      case Repo.insert(changeset) do
        {:ok, event} ->
          broadcast_home()
          {:ok, event}

        {:error, changeset} ->
          {:error, changeset_errors(changeset)}
      end
    end
  end

  defp validate_create_params(params) do
    title = params |> Map.get("title", "") |> to_string() |> String.trim()
    slug = params |> Map.get("slug", "") |> to_string() |> String.trim() |> String.downcase()
    description = params |> Map.get("description", "") |> to_string()
    meta = Meta.from_params(params)
    main_size_raw = params |> Map.get("main_size", "")
    wait_size_raw = params |> Map.get("wait_size", "3")
    password = params |> Map.get("password", "") |> to_string() |> String.trim()

    errors = %{}
    errors = if title == "", do: put_error(errors, :title, "obrigatório"), else: errors
    errors = validate_slug(errors, slug)

    {main_size, errors} =
      validate_size(errors, main_size_raw, :main_size, 1, 500, "número inteiro entre 1 e 500")

    {wait_size, errors} =
      validate_size(errors, wait_size_raw, :wait_size, 0, 100, "número inteiro entre 0 e 100")

    if errors == %{} do
      {:ok,
       %{
         title: title,
         slug: slug,
         description: description,
         meta: meta,
         main_size: main_size,
         wait_size: wait_size,
         password: password,
         category: trimmed(params, "category"),
         local: trimmed(params, "local"),
         starts_at: parse_datetime(params["starts_at"]) || combine_date_time(params),
         ends_at: parse_datetime(params["ends_at"]),
         price_cents: parse_price(params["price"]),
         pix_key: trimmed(params, "pix_key")
       }}
    else
      {:error, errors}
    end
  end

  defp trimmed(params, key) do
    case params |> Map.get(key) |> to_string() |> String.trim() do
      "" -> nil
      value -> value
    end
  end

  # The form asks for a date and a time separately, because that is how someone
  # thinks about it. Stored as one instant, since "Wednesday 7pm" cannot be
  # sorted or turned into a calendar entry.
  #
  # The pair is read as local time in Brasília (UTC-3, no DST), which is the
  # wall clock everyone in the group is reading.
  defp combine_date_time(params) do
    with date when is_binary(date) <- params["date"],
         {:ok, date} <- Date.from_iso8601(String.trim(date)),
         {:ok, time} <- parse_time(params["time"]),
         {:ok, naive} <- NaiveDateTime.new(date, time) do
      naive |> DateTime.from_naive!("Etc/UTC") |> DateTime.add(3 * 3600, :second)
    else
      _ -> nil
    end
  end

  # A date with no time means the whole day; midnight is the conventional way to
  # say that in a timestamp.
  defp parse_time(nil), do: {:ok, ~T[00:00:00]}

  defp parse_time(value) when is_binary(value) do
    case String.trim(value) do
      "" -> {:ok, ~T[00:00:00]}
      trimmed -> Time.from_iso8601(trimmed <> ":00")
    end
  end

  defp parse_time(_), do: {:ok, ~T[00:00:00]}

  defp parse_datetime(%DateTime{} = value), do: value

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end

  defp parse_datetime(_), do: nil

  # People write an amount the way they say it: "15", "R$ 15", "15,00". All three
  # mean the same thing, and rejecting two of them would be pedantry.
  defp parse_price(value) when is_integer(value), do: value

  defp parse_price(value) when is_binary(value) do
    digits = String.replace(value, ~r/[^\d,.]/, "")

    case Regex.run(~r/^(\d+)(?:[.,](\d{1,2}))?$/, digits) do
      [_, reais] -> String.to_integer(reais) * 100
      [_, reais, cents] -> String.to_integer(reais) * 100 + pad_cents(cents)
      _ -> nil
    end
  end

  defp parse_price(_), do: nil

  defp pad_cents(cents) do
    cents |> String.pad_trailing(2, "0") |> String.to_integer()
  end

  defp validate_slug(errors, ""), do: put_error(errors, :slug, "obrigatório")

  defp validate_slug(errors, slug) do
    cond do
      not Regex.match?(Event.slug_regex(), slug) ->
        put_error(errors, :slug, "use letras minúsculas, números e traços")

      slug_taken?(slug) ->
        put_error(errors, :slug, "já está em uso")

      true ->
        errors
    end
  end

  defp validate_size(errors, raw, field, min, max, message) do
    case parse_int(raw) do
      {:ok, n} when n >= min and n <= max -> {n, errors}
      _ -> {0, put_error(errors, field, message)}
    end
  end

  # Anything a non-admin creates is born hidden: it opens fine by link, so the
  # person who made it can share it in their group, but it stays off the public
  # home page. Otherwise the home page is a wall anyone can post to, and the
  # first abuse is somebody else's problem to clean up.
  #
  # The caller decides, because the context does not know who is asking and
  # should not — but the default is the safe one, so a new call site that forgets
  # to say gets `hidden` rather than a public listing.
  defp initial_status(opts) do
    if Keyword.get(opts, :admin?, false), do: :active, else: :hidden
  end

  defp build_attrs(attrs, status) do
    empty_slots = for _ <- 1..attrs.main_size//1, do: %{name: "", paid: false}

    %{
      slug: attrs.slug,
      title: attrs.title,
      status: status,
      header: Meta.build_header(attrs.meta, attrs.description),
      footer: "",
      main_capacity: attrs.main_size,
      wait_enabled: attrs.wait_size > 0,
      wait_intro: "Lista de reserva",
      main_list: empty_slots,
      wait_list: [],
      password: attrs.password,
      category: attrs.category,
      local: attrs.local,
      starts_at: attrs.starts_at,
      ends_at: attrs.ends_at,
      price_cents: attrs.price_cents,
      pix_key: attrs.pix_key
    }
  end

  defp parse_int(v) when is_integer(v), do: {:ok, v}

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  defp parse_int(_), do: :error

  defp put_error(errors, key, message) do
    Map.update(errors, key, [message], &[message | &1])
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  # ---------- Persistence primitives ----------

  @doc """
  Persists an event struct that has been mutated in memory. Uses the passed
  struct as the original DB state, so callers must not mutate the same struct
  used to derive it.
  """
  @spec save(Event.t()) :: {:ok, Event.t()} | {:error, term()}
  def save(%Event{} = event) do
    original =
      case event.id do
        nil -> %Event{}
        id -> Repo.get!(Event, id)
      end

    original
    |> Event.changeset(Event.attrs_from_struct(event))
    |> Repo.update()
    |> case do
      {:ok, saved} ->
        broadcast(saved)
        broadcast_home()
        {:ok, saved}

      {:error, changeset} ->
        {:error, changeset_errors(changeset)}
    end
  end

  # ---------- Raw editor ----------

  @doc """
  Replaces the whole event (title/header/lists/footer) by parsing the raw
  markdown blob provided by the admin.
  """
  @spec save_raw(Event.t(), String.t()) :: {:ok, Event.t()} | {:error, term()}
  def save_raw(%Event{} = event, raw_content) when is_binary(raw_content) do
    parsed = Parser.parse(raw_content)

    attrs =
      %{
        slug: event.slug,
        status: event.status,
        title: parsed.title,
        header: parsed.header,
        footer: parsed.footer,
        main_capacity: parsed.main_capacity,
        wait_enabled: parsed.wait_enabled,
        wait_intro: parsed.wait_intro,
        main_list: Enum.map(parsed.main_list, &Map.from_struct/1),
        wait_list: Enum.map(parsed.wait_list, &Map.from_struct/1)
      }

    event
    |> Event.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, saved} ->
        broadcast(saved)
        broadcast_home()
        {:ok, saved}

      {:error, changeset} ->
        {:error, changeset_errors(changeset)}
    end
  end

  # ---------- Status changes ----------

  @doc "Changes an event's status."
  def set_status(%Event{} = event, new_status) when new_status in @statuses do
    if new_status == event.status do
      {:ok, event}
    else
      event
      |> Ecto.Changeset.change(status: new_status)
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          broadcast(updated)
          broadcast_home()
          {:ok, updated}

        {:error, changeset} ->
          {:error, changeset_errors(changeset)}
      end
    end
  end

  @doc "Permanently deletes an event."
  def delete(%Event{} = event) do
    case Repo.delete(event) do
      {:ok, _} ->
        broadcast(event, :deleted)
        broadcast_home()
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Clones an event. The clone's title has " Clonado" appended and its slug
  ends in `-clonado` (with a numeric suffix when that is already taken).
  """
  @spec clone(Event.t()) :: {:ok, Event.t()} | {:error, term()}
  def clone(%Event{} = source) do
    clone_slug = unique_clone_slug(source.slug)

    attrs =
      source
      |> Event.attrs_from_struct()
      |> Map.merge(%{
        slug: clone_slug,
        title: source.title <> " Clonado",
        status: :active,
        # RN-52: a repeat copies the setup, not the people. Carrying the list
        # over would open next week's rolê with last week's names already
        # confirmed — and the payment checks with them.
        main_list: empty_slots(source.main_capacity),
        wait_list: []
      })

    changeset =
      %Event{}
      |> Event.changeset(attrs)
      # The copy is its own event, so it gets its own secret: sharing one would
      # let whoever organized the original administer the repeat, and the other
      # way round.
      |> Ecto.Changeset.put_change(:organizer_token, Token.generate_organizer())

    case Repo.insert(changeset) do
      {:ok, clone} ->
        broadcast_home()
        {:ok, clone}

      {:error, changeset} ->
        {:error, changeset_errors(changeset)}
    end
  end

  defp empty_slots(capacity) when is_integer(capacity) and capacity > 0 do
    for _ <- 1..capacity, do: %{name: "", paid: false}
  end

  defp empty_slots(_capacity), do: []

  defp unique_clone_slug(source_slug) do
    base = source_slug <> "-clonado"

    if slug_taken?(base) do
      Stream.iterate(2, &(&1 + 1))
      |> Enum.find_value(fn n ->
        candidate = base <> "-" <> Integer.to_string(n)
        if slug_taken?(candidate), do: nil, else: candidate
      end)
    else
      base
    end
  end

  # ---------- Slug rename ----------

  @doc """
  Renames an event's slug. Returns:

    * `{:ok, updated_event}` on success (including when unchanged),
    * `{:error, :invalid_slug}` when the format is invalid,
    * `{:error, :slug_taken}` when another event already uses the target slug,
    * `{:error, changeset_errors}` on other validation failures.
  """
  @spec rename_slug(Event.t(), String.t()) ::
          {:ok, Event.t()} | {:error, :invalid_slug | :slug_taken | map()}
  def rename_slug(%Event{} = event, new_slug) when is_binary(new_slug) do
    new_slug = new_slug |> String.trim() |> String.downcase()

    cond do
      new_slug == event.slug ->
        {:ok, event}

      not Regex.match?(Event.slug_regex(), new_slug) ->
        {:error, :invalid_slug}

      slug_taken?(new_slug) ->
        {:error, :slug_taken}

      true ->
        old_slug = event.slug

        Multi.new()
        |> Multi.update(:event, Ecto.Changeset.change(event, slug: new_slug))
        |> Repo.transaction()
        |> case do
          {:ok, %{event: updated}} ->
            PubSub.broadcast(@pubsub, topic(old_slug), {:moved, updated})
            broadcast(updated)
            broadcast_home()
            {:ok, updated}

          {:error, :event, changeset, _} ->
            case Keyword.get(changeset.errors, :slug) do
              {_msg, [{:constraint, :unique} | _]} -> {:error, :slug_taken}
              _ -> {:error, changeset_errors(changeset)}
            end
        end
    end
  end

  # ---------- Meta ----------

  @doc """
  Updates the structured meta (local/data/horário) on an event. The free-form
  part of the header is preserved.
  """
  def update_meta(%Event{} = event, %Meta{} = new_meta) do
    {_current_meta, rest} = Meta.extract(event.header)
    new_header = Meta.build_header(new_meta, rest)

    event
    |> Ecto.Changeset.change(header: new_header)
    |> Repo.update()
    |> case do
      {:ok, saved} ->
        broadcast(saved)
        broadcast_home()
        {:ok, saved}

      {:error, changeset} ->
        {:error, changeset_errors(changeset)}
    end
  end

  def update_meta(%Event{} = event, params) when is_map(params) do
    update_meta(event, Meta.from_params(params))
  end

  # ---------- Password ----------

  @doc """
  Sets, changes or clears the event's password. An empty/whitespace value
  clears the password.
  """
  def update_password(%Event{} = event, password) do
    event
    |> Event.changeset(%{password: password})
    |> Repo.update()
    |> case do
      {:ok, saved} ->
        broadcast(saved)
        broadcast_home()
        {:ok, saved}

      {:error, changeset} ->
        {:error, changeset_errors(changeset)}
    end
  end

  # ---------- Payment (price + pix_key) ----------

  @doc """
  Updates the event's payment fields (`price_cents` and `pix_key`).

  Accepts a params map with string keys `"price"` and `"pix_key"`, matching
  what the create form (`EventNewLive`) accepts. Blank values clear the fields,
  which is how the organizer removes a Pix key or turns a paid event into a
  free one.

    * `"price"` — free-form (`"15"`, `"R$ 15"`, `"15,50"`). Nil/blank/invalid
      clears `price_cents`.
    * `"pix_key"` — any DICT-shaped key (phone, CPF, CNPJ, email, random).
      Trimmed; blank clears `pix_key`.
  """
  @spec update_payment(Event.t(), map()) :: {:ok, Event.t()} | {:error, map()}
  def update_payment(%Event{} = event, params) when is_map(params) do
    attrs = %{
      price_cents: parse_price(params["price"]),
      pix_key: trimmed(params, "pix_key")
    }

    event
    |> Event.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, saved} ->
        broadcast(saved)
        broadcast_home()
        {:ok, saved}

      {:error, changeset} ->
        {:error, changeset_errors(changeset)}
    end
  end

  # ---------- Password (continued) ----------

  @doc """
  Constant-time password check against the event's stored value. Returns true
  when the event has no password (i.e. is open to everyone).
  """
  @spec check_password(Event.t(), String.t() | nil) :: boolean()
  def check_password(%Event{password: nil}, _submitted), do: true
  def check_password(%Event{password: ""}, _submitted), do: true

  def check_password(%Event{password: expected}, submitted) when is_binary(submitted) do
    Plug.Crypto.secure_compare(expected, submitted)
  end

  def check_password(%Event{}, _), do: false

  # ---------- List operations ----------

  def add_to_main(%Event{} = event, name, opts \\ []) do
    with :ok <- ensure_signups_open(event),
         {:ok, updated} <- Event.add_to_main(event, name, opts) do
      save(updated)
    end
  end

  def add_to_wait(%Event{} = event, name, opts \\ []) do
    with :ok <- ensure_signups_open(event),
         {:ok, updated} <- Event.add_to_wait(event, name, opts) do
      save(updated)
    end
  end

  @doc """
  The questions this event's join form asks (RN-61).

  Falls back to the default form, so an event that predates custom forms — or
  one nobody configured — still asks for a name.
  """
  @spec form_fields(Event.t()) :: [FormField.t()]
  def form_fields(%Event{form_fields: fields}), do: FormField.for_event(fields)

  @doc """
  Adds a question to the join form.

  The id is derived from the label and kept unique, since it becomes both a form
  field name and a key in the attendee's answers.
  """
  @spec add_form_field(Event.t(), map()) :: {:ok, Event.t()} | {:error, term()}
  def add_form_field(%Event{} = event, params) do
    fields = form_fields(event)
    label = params |> Map.get("label", "") |> to_string() |> String.trim()
    type = params |> Map.get("type", "text") |> to_string()

    cond do
      label == "" ->
        {:error, :empty_label}

      type not in FormField.types() ->
        {:error, :invalid_type}

      length(fields) >= max_form_fields() ->
        {:error, :too_many_fields}

      true ->
        field = %FormField{
          id: FormField.build_id(label, Enum.map(fields, & &1.id)),
          label: label,
          type: type,
          required: Map.get(params, "required") in [true, "true", "on"],
          locked: false
        }

        save(%{event | form_fields: fields ++ [field]})
    end
  end

  @doc """
  Removes a question from the join form.

  Locked fields stay: the name identifies the row, so a list without it would
  have nothing to display (RN-60).
  """
  @spec remove_form_field(Event.t(), String.t()) :: {:ok, Event.t()} | {:error, term()}
  def remove_form_field(%Event{} = event, id) do
    fields = form_fields(event)

    case Enum.find(fields, &(&1.id == id)) do
      nil -> {:error, :not_found}
      %FormField{locked: true} -> {:error, :locked_field}
      _ -> save(%{event | form_fields: Enum.reject(fields, &(&1.id == id))})
    end
  end

  @doc """
  Flips whether a question must be answered.

  A locked field cannot become optional — a row with no name is not a row.
  """
  @spec toggle_form_field_required(Event.t(), String.t()) :: {:ok, Event.t()} | {:error, term()}
  def toggle_form_field_required(%Event{} = event, id) do
    fields = form_fields(event)

    case Enum.find(fields, &(&1.id == id)) do
      nil ->
        {:error, :not_found}

      %FormField{locked: true} ->
        {:error, :locked_field}

      _ ->
        updated =
          Enum.map(fields, fn field ->
            if field.id == id, do: %{field | required: not field.required}, else: field
          end)

        save(%{event | form_fields: updated})
    end
  end

  # Past this, the form stops being a form and becomes a survey nobody finishes.
  defp max_form_fields, do: 8

  @doc """
  Adds someone plus their companions in one action (RN-04).

  Returns `{:ok, event, placed}` with how many landed in each list, so the
  caller can say what actually happened rather than assuming everyone got in.
  """
  @spec add_party(Event.t(), String.t(), pos_integer(), keyword()) ::
          {:ok, Event.t(), map()} | {:error, term()}
  def add_party(%Event{} = event, name, size, opts \\ []) do
    with :ok <- ensure_signups_open(event),
         {:ok, updated, placed} <- Event.add_party(event, name, size, opts),
         {:ok, saved} <- save(updated) do
      {:ok, saved, placed}
    end
  end

  defp ensure_signups_open(%Event{} = event) do
    if Event.locked_signups?(event), do: {:error, :signups_locked}, else: :ok
  end

  def remove_main(%Event{} = event, index), do: save(Event.remove_main(event, index))
  def remove_wait(%Event{} = event, index), do: save(Event.remove_wait(event, index))
  def toggle_paid_main(%Event{} = event, index), do: save(Event.toggle_paid_main(event, index))
  def toggle_paid_wait(%Event{} = event, index), do: save(Event.toggle_paid_wait(event, index))
  def rename_main(%Event{} = event, index, name), do: save(Event.rename_main(event, index, name))
  def rename_wait(%Event{} = event, index, name), do: save(Event.rename_wait(event, index, name))

  def promote(%Event{} = event, index) do
    with :ok <- ensure_signups_open(event),
         {:ok, updated} <- Event.promote(event, index) do
      save(updated)
    end
  end

  def resize_main(%Event{} = event, new_size), do: save(Event.resize_main(event, new_size))

  # ---------- Broadcasts ----------

  defp broadcast(%Event{} = event, kind \\ :updated) do
    PubSub.broadcast(@pubsub, topic(event.slug), {kind, event})
  end

  defp broadcast_home do
    PubSub.broadcast(@pubsub, "events:home", :home_changed)
  end
end

defmodule Rolezinho.Events do
  @moduledoc """
  Context for managing rolezinhos (events) persisted as markdown files.

  Files live under `DATA_PATH` (see config):

    * `DATA_PATH/<slug>.md`         — active events
    * `DATA_PATH/hidden/<slug>.md`  — hidden events (not on home page)
    * `DATA_PATH/done/<slug>.md`    — finished events (not publicly listable)

  Changes are broadcast on the `event:<slug>` PubSub topic so multiple
  connected viewers stay in sync.
  """

  alias Rolezinho.Event
  alias Rolezinho.Event.Meta
  alias Phoenix.PubSub

  @pubsub Rolezinho.PubSub

  @slug_regex ~r/^[a-z0-9](?:[a-z0-9-]{0,60}[a-z0-9])?$/

  @statuses [:active, :hidden, :done]

  # ---------- Storage layout ----------

  @doc "Base directory where markdown files live."
  def data_path do
    Application.get_env(:rolezinho, :data_path, "priv/data")
  end

  def status_dir(:active), do: data_path()
  def status_dir(:hidden), do: Path.join(data_path(), "hidden")
  def status_dir(:done), do: Path.join(data_path(), "done")

  def file_path(slug, status) when status in @statuses do
    Path.join(status_dir(status), slug <> ".md")
  end

  @doc "PubSub topic for a specific slug."
  def topic(slug), do: "event:" <> slug

  @doc "Subscribes the caller to updates for a given slug."
  def subscribe(slug) do
    PubSub.subscribe(@pubsub, topic(slug))
  end

  @doc "Subscribes the caller to the home-page updates."
  def subscribe_home do
    PubSub.subscribe(@pubsub, "events:home")
  end

  # ---------- Listing ----------

  @doc "Lists active events (used on the home page)."
  def list_active, do: do_list(:active)

  @doc "Lists hidden events."
  def list_hidden, do: do_list(:hidden)

  @doc "Lists done events."
  def list_done, do: do_list(:done)

  defp do_list(status) do
    status
    |> status_dir()
    |> File.ls()
    |> case do
      {:ok, files} -> files
      {:error, _} -> []
    end
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.map(fn file ->
      slug = String.trim_trailing(file, ".md")
      load(slug, status)
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.title)
  end

  # ---------- Fetching ----------

  @doc """
  Loads an event by slug in the given status. Returns nil if not found.
  """
  def load(slug, status) when status in @statuses do
    path = file_path(slug, status)

    with true <- File.exists?(path),
         {:ok, content} <- File.read(path) do
      Event.parse(content, slug: slug, status: status)
    else
      _ -> nil
    end
  end

  @doc """
  Finds an event by slug across active + hidden + done. Returns nil if not found.

  Use `visibility: :public` to exclude done events.
  """
  def find(slug, opts \\ []) do
    visibility = Keyword.get(opts, :visibility, :any)

    statuses =
      case visibility do
        :public -> [:active, :hidden]
        :any -> [:active, :hidden, :done]
        :active -> [:active]
      end

    Enum.find_value(statuses, fn status -> load(slug, status) end)
  end

  @doc "Returns true when a slug already exists in any status."
  def slug_taken?(slug) do
    Enum.any?(@statuses, &File.exists?(file_path(slug, &1)))
  end

  # ---------- Creation ----------

  @doc """
  Creates a new event from admin form params. Returns `{:ok, event}` or `{:error, changeset_like_map}`.

  Expected keys (strings): "title", "slug", "description", "main_size", "wait_size".
  """
  def create(params) when is_map(params) do
    with {:ok, attrs} <- validate_create_params(params) do
      event = build_event(attrs)

      case write_event(event) do
        :ok ->
          broadcast_home()
          {:ok, event}

        {:error, reason} ->
          {:error, %{base: [to_string(reason)]}}
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

    errors = %{}

    errors =
      if title == "", do: put_error(errors, :title, "obrigatório"), else: errors

    errors =
      cond do
        slug == "" ->
          put_error(errors, :slug, "obrigatório")

        not Regex.match?(@slug_regex, slug) ->
          put_error(errors, :slug, "use letras minúsculas, números e traços")

        slug_taken?(slug) ->
          put_error(errors, :slug, "já está em uso")

        true ->
          errors
      end

    {main_size, errors} =
      case parse_int(main_size_raw) do
        {:ok, n} when n >= 1 and n <= 500 ->
          {n, errors}

        _ ->
          {0, put_error(errors, :main_size, "número inteiro entre 1 e 500")}
      end

    {wait_size, errors} =
      case parse_int(wait_size_raw) do
        {:ok, n} when n >= 0 and n <= 100 ->
          {n, errors}

        _ ->
          {0, put_error(errors, :wait_size, "número inteiro entre 0 e 100")}
      end

    if errors == %{} do
      {:ok,
       %{
         title: title,
         slug: slug,
         description: description,
         meta: meta,
         main_size: main_size,
         wait_size: wait_size
       }}
    else
      {:error, errors}
    end
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

  defp build_event(attrs) do
    empty = %Rolezinho.Event.Attendee{}

    %Event{
      slug: attrs.slug,
      status: :active,
      title: attrs.title,
      header: Meta.build_header(attrs.meta, attrs.description),
      main_capacity: attrs.main_size,
      main_list: List.duplicate(empty, attrs.main_size),
      wait_enabled: attrs.wait_size > 0,
      wait_intro: "Lista de reserva",
      wait_list: [],
      footer: ""
    }
  end

  # ---------- Mutating operations ----------

  @doc "Rewrites the event's file with the current contents."
  def save(%Event{} = event) do
    case write_event(event) do
      :ok ->
        broadcast(event)
        broadcast_home()
        {:ok, event}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Replaces the raw markdown content on disk (used by the raw editor)."
  def save_raw(%Event{} = event, raw_content) when is_binary(raw_content) do
    path = file_path(event.slug, event.status)

    case File.write(path, raw_content) do
      :ok ->
        reloaded = load(event.slug, event.status)
        broadcast(reloaded)
        broadcast_home()
        {:ok, reloaded}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Changes an event's status by moving its file between directories."
  def set_status(%Event{} = event, new_status) when new_status in @statuses do
    if new_status == event.status do
      {:ok, event}
    else
      from = file_path(event.slug, event.status)
      to = file_path(event.slug, new_status)

      File.mkdir_p!(Path.dirname(to))

      case File.rename(from, to) do
        :ok ->
          updated = %Event{event | status: new_status}
          broadcast(updated)
          broadcast_home()
          {:ok, updated}

        {:error, :exdev} ->
          # Cross-device rename fallback: copy + remove.
          with :ok <- File.cp(from, to),
               :ok <- File.rm(from) do
            updated = %Event{event | status: new_status}
            broadcast(updated)
            broadcast_home()
            {:ok, updated}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc "Permanently deletes an event."
  def delete(%Event{} = event) do
    path = file_path(event.slug, event.status)

    case File.rm(path) do
      :ok ->
        broadcast(event, :deleted)
        broadcast_home()
        :ok

      {:error, :enoent} ->
        broadcast_home()
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates the structured meta (local/data/horário) on an event. The free-form
  part of the header is preserved. Pass a `%Rolezinho.Event.Meta{}` struct or
  a params map (typically from a form submission).
  """
  def update_meta(%Event{} = event, %Meta{} = new_meta) do
    {_current_meta, rest} = Meta.extract(event.header)
    updated = %Event{event | header: Meta.build_header(new_meta, rest)}
    save(updated)
  end

  def update_meta(%Event{} = event, params) when is_map(params) do
    update_meta(event, Meta.from_params(params))
  end

  # Public helpers that mutate + persist in one shot.

  def add_to_main(%Event{} = event, name) do
    with {:ok, updated} <- Event.add_to_main(event, name) do
      save(updated)
    end
  end

  def add_to_wait(%Event{} = event, name) do
    with {:ok, updated} <- Event.add_to_wait(event, name) do
      save(updated)
    end
  end

  def remove_main(%Event{} = event, index), do: save(Event.remove_main(event, index))
  def remove_wait(%Event{} = event, index), do: save(Event.remove_wait(event, index))
  def toggle_paid_main(%Event{} = event, index), do: save(Event.toggle_paid_main(event, index))
  def toggle_paid_wait(%Event{} = event, index), do: save(Event.toggle_paid_wait(event, index))
  def rename_main(%Event{} = event, index, name), do: save(Event.rename_main(event, index, name))
  def rename_wait(%Event{} = event, index, name), do: save(Event.rename_wait(event, index, name))

  def promote(%Event{} = event, index) do
    with {:ok, updated} <- Event.promote(event, index) do
      save(updated)
    end
  end

  def resize_main(%Event{} = event, new_size), do: save(Event.resize_main(event, new_size))

  # ---------- File I/O ----------

  defp write_event(%Event{} = event) do
    File.mkdir_p!(status_dir(event.status))
    path = file_path(event.slug, event.status)
    File.write(path, Event.render(event))
  end

  defp broadcast(%Event{} = event, kind \\ :updated) do
    PubSub.broadcast(@pubsub, topic(event.slug), {kind, event})
  end

  defp broadcast_home do
    PubSub.broadcast(@pubsub, "events:home", :home_changed)
  end
end

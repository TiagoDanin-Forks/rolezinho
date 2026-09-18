defmodule Rolezinho.Groups do
  @moduledoc """
  Context for managing groups of events.

  Groups bundle events under one page (`/g/:slug`). A group can be public
  (appears on the home listing) or hidden (reachable only by URL), and
  optionally password-protected. When a group is password-protected the whole
  page is hidden behind the gate — nothing else, not even the group name, is
  rendered until the visitor unlocks — and events belonging to it inherit that
  gate on their own page as well.

  A passwordless group cannot be edited by a non-admin. That is the deliberate
  cost of not requiring a password at creation: without one, there is no
  bearer secret at all for the group beyond the admin password.
  """

  import Ecto.Query, warn: false

  alias Phoenix.PubSub
  alias Rolezinho.Event
  alias Rolezinho.Events
  alias Rolezinho.Group
  alias Rolezinho.Repo

  @pubsub Rolezinho.PubSub

  @doc "PubSub topic for a specific group slug."
  def topic(slug), do: "group:" <> slug

  @doc "Subscribes the caller to updates for a given group slug."
  def subscribe(slug), do: PubSub.subscribe(@pubsub, topic(slug))

  # ---------- Listing ----------

  @doc """
  Lists groups visible on the public home page (visibility: public).

  Ordered by name — groups do not carry their own timestamp of relevance the
  way events do (there is no "when it happens" for a bundle), so alphabetical
  is the only ordering that stays stable across refreshes.
  """
  def list_public do
    from(g in Group, where: g.visibility == ^:public, order_by: [asc: g.name])
    |> Repo.all()
  end

  @doc "Lists every group, regardless of visibility. Admin-facing."
  def list_all do
    from(g in Group, order_by: [asc: g.name])
    |> Repo.all()
  end

  # ---------- Fetching ----------

  @doc "Finds a group by slug. Returns nil if not found."
  @spec find(String.t()) :: Group.t() | nil
  def find(slug) when is_binary(slug) do
    Repo.get_by(Group, slug: slug)
  end

  @doc "Finds a group by id. Returns nil if not found."
  @spec get(integer() | nil) :: Group.t() | nil
  def get(nil), do: nil
  def get(id), do: Repo.get(Group, id)

  @doc "Returns true when a group slug already exists."
  def slug_taken?(slug) do
    from(g in Group, where: g.slug == ^slug, select: 1)
    |> Repo.exists?()
  end

  @doc """
  Lists events belonging to `group`.

    * `visibility: :public` — active + payments_only (default listing on the
      group page)
    * `visibility: :with_hidden` — includes hidden events (admin/organizer view)
    * `visibility: :any` — includes done events too

  Hidden events are never shown on the group page even to unlocked visitors —
  they stay reachable by their own URL. See PRODUCT.md.
  """
  def list_events(%Group{id: id}, opts \\ []) do
    statuses =
      case Keyword.get(opts, :visibility, :public) do
        :public -> Event.open_statuses()
        :with_hidden -> Event.public_statuses()
        :any -> Event.statuses()
      end

    from(e in Event,
      where: e.group_id == ^id and e.status in ^statuses,
      order_by: [asc_nulls_last: e.starts_at, asc: e.title]
    )
    |> Repo.all()
  end

  # ---------- Creation ----------

  @doc """
  Creates a new group from user-supplied params.

  Expected keys (strings): `name`, `slug`, optionally `password`, `visibility`.
  Visibility defaults to `"public"`.

  `opts[:created_by_user_id]` is set from server-held session state — the
  same mass-assignment reasoning as everywhere else: accepting it in `params`
  would let a form POST hand ownership to anyone by id (SECURITY.md §4).
  """
  def create(params, opts \\ []) when is_map(params) do
    attrs = %{
      name: params |> Map.get("name", "") |> to_string() |> String.trim(),
      slug: params |> Map.get("slug", "") |> to_string() |> String.trim() |> String.downcase(),
      password: params |> Map.get("password", "") |> to_string(),
      visibility: parse_visibility(params["visibility"])
    }

    created_by_user_id = Keyword.get(opts, :created_by_user_id)

    changeset =
      %Group{}
      |> Group.changeset(attrs)
      |> Ecto.Changeset.put_change(:created_by_user_id, created_by_user_id)

    case Repo.insert(changeset) do
      {:ok, group} ->
        broadcast_home()
        {:ok, group}

      {:error, changeset} ->
        {:error, changeset_errors(changeset)}
    end
  end

  defp parse_visibility("hidden"), do: :hidden
  defp parse_visibility(:hidden), do: :hidden
  defp parse_visibility(_), do: :public

  # ---------- Updates ----------

  @doc """
  Renames a group. Anyone with edit access (unlocked or admin) may call this.
  """
  def update_name(%Group{} = group, name) when is_binary(name) do
    group
    |> Group.changeset(%{name: name})
    |> Repo.update()
    |> case do
      {:ok, saved} ->
        broadcast(saved)
        {:ok, saved}

      {:error, changeset} ->
        {:error, changeset_errors(changeset)}
    end
  end

  @doc """
  Sets, changes or clears the group's password.

  Note: turning a passwordless group into a password-protected one is an admin
  operation upstream — a non-admin cannot reach this function on a passwordless
  group, because it has no edit surface for them.
  """
  def update_password(%Group{} = group, password) do
    group
    |> Group.changeset(%{password: password})
    |> Repo.update()
    |> case do
      {:ok, saved} ->
        broadcast(saved)
        {:ok, saved}

      {:error, changeset} ->
        {:error, changeset_errors(changeset)}
    end
  end

  @doc """
  Sets the group's visibility. Admin-only upstream.
  """
  def update_visibility(%Group{} = group, visibility) when visibility in [:public, :hidden] do
    group
    |> Group.changeset(%{visibility: visibility})
    |> Repo.update()
    |> case do
      {:ok, saved} ->
        broadcast(saved)
        # Visibility affects the public listing, so nudge the home view.
        broadcast_home()
        {:ok, saved}

      {:error, changeset} ->
        {:error, changeset_errors(changeset)}
    end
  end

  # ---------- Deletion ----------

  @doc """
  Deletes a group.

  Per product decision, deleting a group marks all of its events as `:hidden`
  (occult) first, so that events don't suddenly reappear on the public home
  page as a side-effect of removing their bundle. The DB-level
  `on_delete: :nilify_all` sets `group_id` to `NULL` afterwards; the two
  together mean "the events survive, but they stay off the front door".

  Admin-only upstream.
  """
  def delete(%Group{} = group) do
    events = list_events(group, visibility: :any)

    Enum.each(events, fn event ->
      if event.status in [:active, :payments_only] do
        # We bypass `set_status/2`'s no-op guard by calling it directly — the
        # only case it ignores is the same-status one.
        Events.set_status(event, :hidden)
      end
    end)

    case Repo.delete(group) do
      {:ok, _} ->
        broadcast(group, :deleted)
        broadcast_home()
        {:ok, group}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------- Password ----------

  @doc """
  Constant-time password check against the group's stored value.

  Returns true when the group has no password (i.e. is open to everyone).
  """
  @spec check_password(Group.t(), String.t() | nil) :: boolean()
  def check_password(%Group{password: nil}, _submitted), do: true
  def check_password(%Group{password: ""}, _submitted), do: true

  def check_password(%Group{password: expected}, submitted) when is_binary(submitted) do
    Plug.Crypto.secure_compare(expected, submitted)
  end

  def check_password(%Group{}, _), do: false

  # ---------- Broadcasts ----------

  defp broadcast(%Group{} = group, kind \\ :updated) do
    PubSub.broadcast(@pubsub, topic(group.slug), {kind, group})
  end

  # Reuses the events home topic — the home page listens for anything that
  # changes what it shows, groups and events alike.
  defp broadcast_home do
    PubSub.broadcast(@pubsub, "events:home", :home_changed)
  end

  # ---------- Helpers ----------

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

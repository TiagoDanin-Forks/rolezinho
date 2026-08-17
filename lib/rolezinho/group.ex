defmodule Rolezinho.Group do
  @moduledoc """
  A bundle of events that share a page at `/g/:slug`.

  A group has a slug (immutable after creation, per product spec), a name, an
  optional password and a visibility flag. Public groups appear on the home
  page; hidden ones are reachable only by direct URL. Events belonging to a
  group never appear on the home page — the group is what represents them.

  The password mirrors the event password (SECURITY.md §3): plaintext by
  deliberate decision, because it is shared in the same message that carries
  the link and must be readable back. It is friction, not secrecy.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Rolezinho.Event
  alias Rolezinho.Group

  @visibilities [:public, :hidden]

  @slug_regex Event.slug_regex()

  schema "groups" do
    field :slug, :string
    field :name, :string, default: ""
    field :password, :string
    field :visibility, Ecto.Enum, values: @visibilities, default: :public

    has_many :events, Event

    timestamps(type: :utc_datetime)
  end

  @type visibility :: :public | :hidden

  @type t :: %__MODULE__{
          id: integer() | nil,
          slug: String.t() | nil,
          name: String.t(),
          password: String.t() | nil,
          visibility: visibility(),
          events: [Event.t()] | Ecto.Association.NotLoaded.t()
        }

  @doc "Valid visibility values."
  def visibilities, do: @visibilities

  @doc "Returns true when the group has a password set."
  @spec password_protected?(t()) :: boolean()
  def password_protected?(%Group{password: p}) when is_binary(p) and p != "", do: true
  def password_protected?(%Group{}), do: false

  @doc """
  Returns true when the caller has enough access to see the group's contents
  (name, event list, etc.) — as opposed to the unlock panel only.

  Admin sees everything; a public group with no password is open to anyone; a
  password-protected group requires an entry in `unlocked_groups`.
  """
  @spec accessible?(t(), boolean(), MapSet.t()) :: boolean()
  def accessible?(%Group{} = group, admin?, %MapSet{} = unlocked_groups) do
    cond do
      admin? -> true
      not password_protected?(group) -> true
      true -> MapSet.member?(unlocked_groups, group.slug)
    end
  end

  @doc """
  Returns true when the caller may edit the group (rename, change password,
  add events into it).

  Admin can always edit. A non-admin can only edit a password-protected group
  they have unlocked — passwordless groups are admin-only per the product
  spec (\"Passwordless groups can only be edited by the platform admin\").
  """
  @spec editable_by?(t(), boolean(), MapSet.t()) :: boolean()
  def editable_by?(%Group{} = group, admin?, %MapSet{} = unlocked_groups) do
    cond do
      admin? -> true
      not password_protected?(group) -> false
      true -> MapSet.member?(unlocked_groups, group.slug)
    end
  end

  @doc """
  Full changeset used by the `Rolezinho.Groups` context to persist groups.

  Notes:
    * `slug` is only cast on insertion (a new struct); on update it is stripped
      because the product rule says the slug never changes.
    * `password` normalizes empty/whitespace to `nil`, mirroring events.
  """
  def changeset(%Group{} = group, attrs) do
    fields =
      if is_nil(group.id) do
        [:slug, :name, :password, :visibility]
      else
        # Immutable after creation — no rename, no admin override. This mirrors
        # the spec: "Group slugs never change once created."
        [:name, :password, :visibility]
      end

    group
    |> cast(attrs, fields)
    |> update_change(:password, &normalize_password/1)
    |> update_change(:name, &normalize_name/1)
    |> maybe_downcase_slug()
    |> validate_required([:slug, :name, :visibility])
    |> validate_length(:name, min: 3, max: 80)
    |> validate_format(:slug, @slug_regex, message: "use letras minúsculas, números e traços")
    |> validate_length(:password, max: 80)
    |> unique_constraint(:slug, message: "já está em uso")
  end

  defp maybe_downcase_slug(changeset) do
    case get_change(changeset, :slug) do
      nil -> changeset
      slug -> put_change(changeset, :slug, slug |> String.trim() |> String.downcase())
    end
  end

  defp normalize_password(nil), do: nil

  defp normalize_password(str) when is_binary(str) do
    case String.trim(str) do
      "" -> nil
      other -> other
    end
  end

  defp normalize_password(_), do: nil

  defp normalize_name(nil), do: ""
  defp normalize_name(str) when is_binary(str), do: String.trim(str)
  defp normalize_name(_), do: ""
end

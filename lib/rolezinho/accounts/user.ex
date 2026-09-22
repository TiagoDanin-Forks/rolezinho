defmodule Rolezinho.Accounts.User do
  @moduledoc """
  A user account, sourced from GitHub OAuth.

  The identity pin is `github_id` — GitHub's numeric id, which never changes.
  `github_login` and the display strings are refreshed on every sign-in from
  the OAuth response. See ADR-0002 for the reasoning.

  Every user-facing string on this schema is untrusted (`github_login`, `name`,
  `email`, `avatar_url` come from GitHub, and GitHub does not validate them for
  us). They are length-bounded here, escaped by default in HEEx, and never fed
  to `raw/1` (SECURITY.md §1).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Rolezinho.Accounts.User

  schema "users" do
    field :github_id, :integer
    field :github_login, :string
    field :name, :string
    field :email, :string
    field :avatar_url, :string

    # Platform-admin capability. Mass-assignment-protected: this field is
    # never in `github_changeset/2`, so it cannot be flipped by a hostile
    # OAuth response or a form POST. Set only via
    # `Rolezinho.Accounts.make_admin_by_handle/1` (or a direct migration).
    field :admin, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: integer() | nil,
          github_id: integer() | nil,
          github_login: String.t() | nil,
          name: String.t() | nil,
          email: String.t() | nil,
          avatar_url: String.t() | nil,
          admin: boolean()
        }

  @doc """
  Changeset for creating or refreshing a user from a GitHub OAuth response.

  Every field except `github_id` may be re-cast on subsequent sign-ins: names
  and avatars change; the numeric id is what stays constant.
  """
  # `:admin` is deliberately NOT cast here — an OAuth callback (or any code
  # path that reuses this changeset) must never be able to hand out admin
  # rights. Flip the flag via `Accounts.make_admin_by_handle/1`.
  def github_changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:github_id, :github_login, :name, :email, :avatar_url])
    |> validate_required([:github_id, :github_login])
    # Same size limits as the DB column. Bounding on the way in keeps a
    # renamed-into-nonsense GitHub login from filling a column.
    |> validate_length(:github_login, max: 80)
    |> validate_length(:name, max: 120)
    |> validate_length(:email, max: 200)
    |> validate_length(:avatar_url, max: 400)
    |> unique_constraint(:github_id)
  end

  @doc """
  Best display name for a user in the UI.

  Prefers the GitHub-provided display name, falls back to the login. Never
  returns an empty string.
  """
  @spec display_name(t()) :: String.t()
  def display_name(%User{name: name}) when is_binary(name) and name != "", do: name
  def display_name(%User{github_login: login}), do: login || ""
end

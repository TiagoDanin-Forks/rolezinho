defmodule Rolezinho.Accounts.User do
  @moduledoc """
  A user account.

  Two identity paths land on the same row:

    * **GitHub OAuth** — `github_id` (never changes) + `github_login`,
      refreshed on every sign-in. The original path (ADR-0002).
    * **Local username + password** — `username` (the canonical handle,
      case-insensitive, unique) + `password_hash` (bcrypt). A signed-in
      user with both filled in can log in either way.

  Every user-facing string here is untrusted. Length-bounded on the way
  in, HEEx-escaped on the way out, never `raw/1`d (SECURITY.md §1).

  The `:password` field is virtual and `:redact` so it never lands in
  a struct dump, log, or inspection. Only `:password_hash` is
  persisted.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Rolezinho.Accounts.User

  # Username rules (product decision, 2026-09):
  #   * 6..32 chars,
  #   * must start with a letter,
  #   * lowercase letters, digits, `_`, `-`, `.`.
  # Stored lowercase; lookups are case-insensitive.
  @username_regex ~r/^[a-z][a-z0-9_.-]{5,31}$/

  # Password rules: min 8, no max, no character-class rules.
  @min_password_length 8

  schema "users" do
    field :github_id, :integer
    field :github_login, :string
    field :name, :string
    field :email, :string
    field :avatar_url, :string

    # The canonical handle: unique across all users, case-insensitive,
    # required. GitHub-authed users get one auto-derived from
    # `github_login` at insert time (see `Rolezinho.Accounts`
    # `find_or_create_by_github/1`). Local-auth users pick their own.
    field :username, :string

    # bcrypt hash of the plaintext password. Nullable — a GitHub-only
    # user won't have one until they set a password from `/me`.
    field :password_hash, :string

    # Virtual + redacted: kept in the changeset for validation and
    # hashing, never persisted, never printed in inspects/logs.
    field :password, :string, virtual: true, redact: true

    # Platform-admin capability. Mass-assignment-protected: this field
    # is never in `github_changeset/2` nor in `register_changeset/2`,
    # so a hostile OAuth response or a rogue POST cannot flip it. Set
    # only via `Rolezinho.Accounts.make_admin_by_handle/1` (or a
    # direct migration).
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
          username: String.t() | nil,
          password_hash: String.t() | nil,
          password: String.t() | nil,
          admin: boolean()
        }

  @doc """
  Changeset for creating or refreshing a user from a GitHub OAuth response.

  `:admin` and `:password_hash` are deliberately not cast here — a
  hostile OAuth response (or a bug that reuses this changeset for a
  form) must not be able to promote or replace credentials.

  `:username` is cast only on insert (when the row has no id yet); a
  subsequent sign-in never renames the user. The caller
  (`Rolezinho.Accounts.find_or_create_by_github/1`) is responsible for
  putting a valid username into `attrs` on the insert path.
  """
  def github_changeset(%User{} = user, attrs) do
    fields =
      if is_nil(user.id) do
        [:github_id, :github_login, :name, :email, :avatar_url, :username]
      else
        [:github_id, :github_login, :name, :email, :avatar_url]
      end

    user
    |> cast(attrs, fields)
    |> validate_required([:github_id, :github_login])
    |> validate_length(:github_login, max: 80)
    |> validate_length(:name, max: 120)
    |> validate_length(:email, max: 200)
    |> validate_length(:avatar_url, max: 400)
    |> maybe_validate_username()
    |> unique_constraint(:github_id)
    |> unique_constraint(:username)
  end

  @doc """
  Changeset for creating a user via the local (username + password) path.

  Accepts a plain params map with `"username"`, `"password"`, and
  optionally `"email"` and `"name"`. The password is hashed via bcrypt
  and stored on `:password_hash`; the virtual `:password` is cleared
  after hashing so nothing plaintext survives the changeset.

  Same mass-assignment rules as `github_changeset/2`: `:admin`,
  `:github_id`, `:github_login`, `:avatar_url`, `:password_hash` are
  never cast from `attrs`.
  """
  def register_changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:username, :password, :email, :name])
    |> validate_required([:username, :password])
    |> update_change(:username, &normalize_username/1)
    |> validate_length(:email, max: 200)
    |> validate_length(:name, max: 120)
    |> validate_username()
    |> validate_password()
    |> hash_password_if_valid()
    |> unique_constraint(:username)
  end

  @doc """
  Changeset for a signed-in user updating their password.

  Requires `:password` in the params. If the user has no
  `:password_hash` yet (a GitHub-only account setting a password for
  the first time), that's a valid path — no current-password check is
  required. If they do have one, the caller is responsible for
  verifying the current password first (see
  `Accounts.update_password/3`).
  """
  def password_changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password()
    |> hash_password_if_valid()
  end

  @doc """
  Changeset for a signed-in user updating just their email.

  Only `:email` is cast — `:admin`, `:password_hash`, `:username`,
  and everything GitHub-side is mass-assignment-protected. An empty
  or whitespace-only value clears the email (nil on the row), which
  is the same shape a user with no email on file has at
  registration.

  Length is bounded but the value is not format-validated: email is
  optional and unverified (per ADR-0002 amendment), so accepting
  anything the user types keeps the flow honest. If they typo, they
  can fix it here.
  """
  def email_changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:email])
    |> update_change(:email, &normalize_email/1)
    |> validate_length(:email, max: 200)
  end

  # Whitespace-only email collapses to nil so a stray space bar does
  # not leave the user with an unreachable email address.
  defp normalize_email(nil), do: nil

  defp normalize_email(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_email(_), do: nil

  @doc "Regex used to validate the username on creation."
  def username_regex, do: @username_regex

  @doc "Minimum length for a new password."
  def min_password_length, do: @min_password_length

  @doc """
  Best display name for a user in the UI.

  Prefers `name` (GitHub-provided display name or user-typed on
  local signup), then `github_login` (the handle a GitHub user knows
  themselves by), then `username` (the local-auth handle). Never
  returns an empty string.

  Ordering matters: for a GitHub-authed user we derive `username`
  from `github_login` at insert time and may pad it to satisfy the
  6-char minimum (`octo` → `octo00`). The user still recognises
  themselves as `octo`, not `octo00`, so `github_login` wins when
  present.
  """
  @spec display_name(t()) :: String.t()
  def display_name(%User{name: name}) when is_binary(name) and name != "", do: name
  def display_name(%User{github_login: login}) when is_binary(login) and login != "", do: login
  def display_name(%User{username: u}) when is_binary(u) and u != "", do: u
  def display_name(%User{}), do: ""

  # ---------- Internal helpers ----------

  # Only run the format check when `:username` actually changed on the
  # changeset (either explicitly, via cast on insert, or via a rare
  # admin path). Refreshing an existing user's GitHub-side fields must
  # not re-validate their long-standing username.
  defp maybe_validate_username(changeset) do
    case get_change(changeset, :username) do
      nil -> changeset
      _ -> validate_username(changeset)
    end
  end

  defp validate_username(changeset) do
    changeset
    |> update_change(:username, &normalize_username/1)
    |> validate_required([:username])
    |> validate_format(:username, @username_regex,
      message: "6–32 caracteres, começando com letra; letras minúsculas, números, . _ -"
    )
  end

  defp normalize_username(nil), do: nil

  defp normalize_username(value) when is_binary(value),
    do: value |> String.trim() |> String.downcase()

  defp normalize_username(_), do: nil

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: @min_password_length, max: 200)
  end

  defp hash_password_if_valid(changeset) do
    password = get_change(changeset, :password)

    cond do
      is_binary(password) and changeset.valid? ->
        changeset
        |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
        # Clear the plaintext so nothing outside this function ever
        # sees it, even if the changeset is later inspected.
        |> delete_change(:password)

      true ->
        changeset
    end
  end
end

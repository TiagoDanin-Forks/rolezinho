defmodule Rolezinho.Accounts do
  @moduledoc """
  Context for user accounts.

  Two identity paths land here (ADR-0002, amended 2026-09):

    * **GitHub OAuth** — `find_or_create_by_github/1` upserts by
      `github_id`, refreshing `github_login`/`name`/`avatar_url` on
      every sign-in. On first insert it auto-derives a `:username`
      from `lower(github_login)`, suffixing with a number on collision
      with an existing local-auth user.

    * **Local username + password** — `register_user/1` inserts a row
      keyed on `:username` with a bcrypt `:password_hash`.
      `authenticate_user/2` verifies the pair in constant time.

  Both paths produce the same session (`:current_user_id`) and the
  same downstream widening (`user.admin` flips `:current_admin?`,
  persisted group unlocks merge into `:unlocked_groups`).
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Rolezinho.Accounts.User
  alias Rolezinho.Repo

  @doc """
  Loads a user by primary key. Returns `nil` when not found (or when `nil` is
  passed, so the session-key `:current_user_id` can be piped in without
  branching).
  """
  @spec get_user(integer() | nil) :: User.t() | nil
  def get_user(nil), do: nil
  def get_user(id) when is_integer(id), do: Repo.get(User, id)

  @doc """
  Finds a user by their numeric GitHub id. Returns `nil` when not found.
  """
  @spec get_by_github_id(integer()) :: User.t() | nil
  def get_by_github_id(github_id) when is_integer(github_id) do
    Repo.get_by(User, github_id: github_id)
  end

  @doc """
  Upserts a user from a normalized GitHub OAuth response.

  `attrs` is expected to have string keys `"github_id"`, `"github_login"`, and
  optionally `"name"`, `"email"`, `"avatar_url"`. Missing optional values map
  to `nil`, matching what GitHub itself sometimes returns for private profiles.

  On the second and subsequent calls for the same `github_id`, the existing
  row is refreshed — no duplicate is ever created.
  """
  @spec find_or_create_by_github(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def find_or_create_by_github(attrs) when is_map(attrs) do
    github_id = attrs |> Map.get("github_id") |> to_integer()

    if is_nil(github_id) do
      # Constructing an explicit changeset lets the caller surface the error the
      # same way as any other validation failure, rather than a `nil` matching
      # error deep in Ecto.
      {:error,
       User.github_changeset(%User{}, attrs)
       |> Changeset.add_error(:github_id, "obrigatório")}
    else
      case get_by_github_id(github_id) do
        nil ->
          # Insert path: auto-derive a `:username` from `github_login`
          # and suffix on collision. `github_login` is already unique
          # per-GitHub-user, so the pool of candidates is small; the
          # loop caps at 100 tries and gives up loudly if we somehow
          # exhaust it (which means production has bigger problems).
          attrs =
            Map.put(attrs, "username", derive_username(Map.get(attrs, "github_login")))

          %User{} |> User.github_changeset(attrs) |> Repo.insert()

        %User{} = user ->
          user |> User.github_changeset(attrs) |> Repo.update()
      end
    end
  end

  # Turns a GitHub login into a valid, unique local username. Same
  # normalization the schema does (`lower`), plus a suffix on
  # collision with an existing local-auth user. Prod audit before
  # ship (2026-09) showed zero collisions on lower(github_login), so
  # the suffix path is defensive rather than routine.
  defp derive_username(nil), do: nil

  defp derive_username(github_login) when is_binary(github_login) do
    base =
      github_login
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9_.-]/u, "")

    base =
      cond do
        base == "" -> "user"
        # Schema regex requires the username to start with a letter;
        # a GitHub login starting with a digit gets prefixed.
        String.match?(base, ~r/^[a-z]/) -> base
        true -> "u-" <> base
      end

    # Pad to the 6-char minimum so a short handle ("me", "ex") still
    # satisfies the length rule. Padding character is `0`, matching
    # the allowed alphabet.
    base = String.pad_trailing(base, 6, "0")

    unique_username(base, 0, 100)
  end

  defp unique_username(_base, tries, tries), do: raise("could not derive a unique username")

  defp unique_username(base, n, max_tries) do
    candidate = if n == 0, do: base, else: "#{base}#{n}"

    case Repo.get_by(User, username: candidate) do
      nil -> candidate
      %User{} -> unique_username(base, n + 1, max_tries)
    end
  end

  @doc """
  Case-insensitive lookup by `:username`. The username column stores
  lowercase (see `User.register_changeset/2`) so a downcase on the way
  in is enough — no need for a `lower(?)` SQL fragment here.
  """
  @spec get_by_username(String.t()) :: User.t() | nil
  def get_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: String.downcase(String.trim(username)))
  end

  def get_by_username(_), do: nil

  @doc """
  Registers a new local-auth user from a params map.

  Expected string keys: `"username"`, `"password"`, and optionally
  `"email"` and `"name"`. Password rules and username format live on
  the schema (see `User.register_changeset/2`).

  Returns `{:ok, user}` on success and `{:error, changeset}` on
  validation failure (invalid username, duplicate username, weak
  password, etc.). The controller re-renders the form with the
  changeset's errors attached to the fields.
  """
  @spec register_user(map()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def register_user(attrs) when is_map(attrs) do
    %User{}
    |> User.register_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Verifies a `(username, password)` pair.

  Returns `{:ok, user}` on match, `{:error, :invalid_credentials}` on
  anything else — missing user, missing password_hash (GitHub-only
  account), or wrong password.

  Constant-time: when the user is missing we still run a dummy bcrypt
  verify via `Bcrypt.no_user_verify/0` so the timing signal doesn't
  reveal whether a username exists.
  """
  @spec authenticate_user(String.t() | nil, String.t() | nil) ::
          {:ok, User.t()} | {:error, :invalid_credentials}
  def authenticate_user(username, password) when is_binary(username) and is_binary(password) do
    case get_by_username(username) do
      %User{password_hash: hash} = user when is_binary(hash) ->
        if Bcrypt.verify_pass(password, hash) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end

      _ ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  def authenticate_user(_username, _password) do
    Bcrypt.no_user_verify()
    {:error, :invalid_credentials}
  end

  @doc """
  Sets or replaces a user's password.

  If the user already has a `:password_hash`, the caller must supply
  `current_password` and it must match (so a stolen session can't
  quietly reset the password); if they don't, a first-time password
  is fine without the check. Meant to be called from `/me` by the
  signed-in user themselves.
  """
  @spec update_password(User.t(), String.t() | nil, String.t()) ::
          {:ok, User.t()} | {:error, :invalid_current_password | Changeset.t()}
  def update_password(%User{password_hash: hash} = user, current_password, new_password)
      when is_binary(hash) do
    if is_binary(current_password) and Bcrypt.verify_pass(current_password, hash) do
      do_update_password(user, new_password)
    else
      Bcrypt.no_user_verify()
      {:error, :invalid_current_password}
    end
  end

  def update_password(%User{} = user, _current_password, new_password) do
    do_update_password(user, new_password)
  end

  defp do_update_password(%User{} = user, new_password) do
    user
    |> User.password_changeset(%{"password" => new_password})
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Flags an existing user as a platform admin, keyed by their GitHub login.

  Meant for a remote-console session in production: the shared
  `ADMIN_PASSWORD` is the emergency bypass, this is how you hand out
  durable admin capability. From an IEx prompt:

      iex> Rolezinho.Accounts.make_admin_by_handle("lubien")
      {:ok, %Rolezinho.Accounts.User{admin: true, ...}}

  The lookup is case-insensitive to match how GitHub treats logins (they
  are collision-scoped case-insensitively over there, but stored as-typed
  in this DB, so a callsite from memory should not have to remember the
  exact casing). Returns `{:error, :not_found}` when the user has never
  signed in — accounts here are created on first sign-in, so there is no
  "pre-create by handle" flow.

  Idempotent: calling it on an already-admin user is a no-op that still
  returns `{:ok, user}`.
  """
  @spec make_admin_by_handle(String.t()) :: {:ok, User.t()} | {:error, :not_found}
  def make_admin_by_handle(login) when is_binary(login) do
    trimmed = login |> String.trim() |> String.trim_leading("@")

    if trimmed == "" do
      {:error, :not_found}
    else
      case get_by_github_login(trimmed) do
        %User{admin: true} = user ->
          {:ok, user}

        %User{} = user ->
          user
          |> Ecto.Changeset.change(admin: true)
          |> Repo.update()

        nil ->
          {:error, :not_found}
      end
    end
  end

  # Case-insensitive lookup on `github_login`. Two GitHub users cannot share
  # a login (case-insensitive over on their end), so this can safely return
  # at most one row.
  defp get_by_github_login(login) when is_binary(login) do
    import Ecto.Query, only: [from: 2]

    Repo.one(
      from u in User,
        where: fragment("lower(?) = ?", u.github_login, ^String.downcase(login)),
        limit: 1
    )
  end

  # Accepts an integer (already parsed) or a string (as the OAuth adapter
  # sometimes hands it back). Anything else collapses to nil so the caller
  # returns a proper validation error rather than crashing.
  defp to_integer(id) when is_integer(id), do: id

  defp to_integer(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp to_integer(_), do: nil
end

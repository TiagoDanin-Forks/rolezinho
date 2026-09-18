defmodule Rolezinho.Accounts do
  @moduledoc """
  Context for user accounts backed by GitHub OAuth.

  There is exactly one identity provider (ADR-0002). A user is
  find-or-created by their `github_id` on every sign-in; the changing fields
  (`github_login`, `name`, `avatar_url`) are refreshed each time.

  This context is intentionally small: users exist so we can gate creation and
  attribute ownership, and for nothing else. There is no per-user preferences,
  no per-user settings, and no listing of \"my events\" beyond what the
  ownership pointer already gives us.
  """

  import Ecto.Query, warn: false

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
       |> Ecto.Changeset.add_error(:github_id, "obrigatório")}
    else
      case get_by_github_id(github_id) do
        nil -> %User{} |> User.github_changeset(attrs) |> Repo.insert()
        %User{} = user -> user |> User.github_changeset(attrs) |> Repo.update()
      end
    end
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

defmodule RolezinhoWeb.SessionController do
  @moduledoc """
  Local (username + password) auth endpoints.

  Two POST actions:

    * `create/2` — verifies credentials, drops the user id into the
      session, redirects to `return_to` (validated) or home.
    * `register/2` — creates a new user and logs them in.

  Both wrap `RolezinhoWeb.Plugs.User.put_current_user/2` so all
  downstream widening (`user.admin` → `current_admin?`, persisted group
  unlocks) works exactly the same as the GitHub OAuth path.

  On validation failure we re-render `SignInLive` with the changeset
  errors and the submitted (safe) params, so the user sees inline
  errors instead of losing their input.
  """
  use RolezinhoWeb, :controller

  alias Rolezinho.Accounts
  alias Rolezinho.Accounts.User
  alias RolezinhoWeb.Plugs.User, as: UserPlug

  # ---------- login ----------

  def create(conn, params) do
    username = params |> Map.get("username", "") |> to_string()
    password = params |> Map.get("password", "") |> to_string()
    return_to = params |> Map.get("return_to", "") |> to_string()

    case Accounts.authenticate_user(username, password) do
      {:ok, %User{} = user} ->
        conn
        |> UserPlug.put_current_user(user.id)
        |> put_flash(:info, "Beleza, entrou como #{User.display_name(user)}.")
        |> redirect(to: safe_return_to(return_to))

      {:error, :invalid_credentials} ->
        # Re-render `/entrar` with a generic error. Never disclose
        # whether the username exists.
        conn
        |> put_flash(:error, "Usuário ou senha inválidos.")
        |> redirect(to: sign_in_path(return_to, "entrar", username: username))
    end
  end

  # ---------- register ----------

  def register(conn, params) do
    attrs = %{
      "username" => Map.get(params, "username", ""),
      "password" => Map.get(params, "password", ""),
      "email" => trim_or_nil(Map.get(params, "email")),
      "name" => trim_or_nil(Map.get(params, "name"))
    }

    return_to = params |> Map.get("return_to", "") |> to_string()

    case Accounts.register_user(attrs) do
      {:ok, %User{} = user} ->
        conn
        |> UserPlug.put_current_user(user.id)
        |> put_flash(:info, "Conta criada! Bem-vindo, #{User.display_name(user)}.")
        |> redirect(to: safe_return_to(return_to))

      {:error, changeset} ->
        # Pipe the top error into a flash and bounce back to the
        # register tab with the failed input pre-filled. Detail-level
        # errors are surfaced inline once the form re-renders on the
        # subsequent GET — SignInLive reads the flash to seed a light
        # error banner. Sensitive fields (password) are not carried
        # back in the query string.
        conn
        |> put_flash(:error, first_error_message(changeset))
        |> redirect(
          to:
            sign_in_path(return_to, "registrar",
              username: Map.get(attrs, "username"),
              email: Map.get(attrs, "email"),
              name: Map.get(attrs, "name")
            )
        )
    end
  end

  # ---------- helpers ----------

  defp trim_or_nil(nil), do: nil

  defp trim_or_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      other -> other
    end
  end

  defp trim_or_nil(_), do: nil

  # Open-redirect gate — same rule the OAuth callback uses. Local
  # paths only; protocol-relative "//evil.example" rejected.
  defp safe_return_to(nil), do: ~p"/"
  defp safe_return_to(""), do: ~p"/"

  defp safe_return_to(path) when is_binary(path) do
    if String.starts_with?(path, "/") and not String.starts_with?(path, "//") do
      path
    else
      ~p"/"
    end
  end

  defp safe_return_to(_), do: ~p"/"

  # Builds the `/entrar` URL preserving return_to + a `tab=` marker so
  # the LiveView opens on the same tab the user was on when the form
  # bounced. Filters nil / empty entries out of the extras query.
  defp sign_in_path(return_to, tab, extras) do
    base = %{"tab" => tab}
    base = if return_to != "", do: Map.put(base, "return_to", return_to), else: base

    query =
      extras
      |> Enum.into(base, fn {k, v} -> {to_string(k), v} end)
      |> Enum.reject(fn {_, v} -> is_nil(v) or v == "" end)
      |> URI.encode_query()

    "/entrar?" <> query
  end

  # Picks the first error message from an Ecto.Changeset — good enough
  # for a flash banner; the LiveView shows the full errors inline.
  defp first_error_message(changeset) do
    case changeset.errors do
      [{field, {message, _}} | _] -> "#{field}: #{translate_message(message)}"
      _ -> "Não deu pra criar a conta. Confira os campos."
    end
  end

  defp translate_message("has already been taken"), do: "já em uso"
  defp translate_message("can't be blank"), do: "obrigatório"
  defp translate_message(other), do: other
end

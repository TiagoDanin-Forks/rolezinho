defmodule RolezinhoWeb.PasswordResetController do
  @moduledoc """
  The two POST actions of the local-auth password-reset flow (2026-09
  amendment to ADR-0002). GET rendering lives in `ForgotPasswordLive`
  and `ResetPasswordLive` — this controller only writes.

  Actions:

    * `create/2` — accepts a username or email, calls
      `Accounts.request_password_reset/2`, and always redirects to
      `/entrar` with a generic success flash. Whether the user exists
      or has an email on file is not disclosed to the caller.
    * `update/2` — accepts the token from the URL and a new password,
      redeems the token, signs the user in, and redirects home. On
      failure (invalid/expired/used token, weak password) it bounces
      back to the reset form with an error flash.
  """
  use RolezinhoWeb, :controller

  alias Rolezinho.Accounts
  alias Rolezinho.Accounts.ResetRateLimiter
  alias Rolezinho.Accounts.User
  alias RolezinhoWeb.Plugs.User, as: UserPlug

  # ---------- request a reset ----------

  def create(conn, params) do
    identifier = params |> Map.get("identifier", "") |> to_string()

    # Rate-limit before any DB work. On limit, we silently skip the
    # reset request but still land on the same generic flash — a
    # "you're throttled" message would be a signal the anti-
    # enumeration story is meant to hide.
    case ResetRateLimiter.check(client_ip(conn), identifier) do
      :ok ->
        url_builder = fn token ->
          url(conn, ~p"/entrar/nova-senha/#{token}")
        end

        :ok = Accounts.request_password_reset(identifier, url_builder)

      {:error, :rate_limited} ->
        :ok
    end

    conn
    # Deliberately generic: says the same thing whether or not an
    # account with that identifier exists, or has an email on file,
    # or the caller was rate-limited. If the request lands, the
    # email lands.
    |> put_flash(
      :info,
      "Se existe uma conta com esse dado e email cadastrado, o link foi enviado."
    )
    |> redirect(to: ~p"/entrar")
  end

  # ---------- redeem a token and set a new password ----------

  def update(conn, %{"token" => token} = params) do
    password = params |> Map.get("password", "") |> to_string()

    case Accounts.reset_password_with_token(token, password) do
      {:ok, %User{} = user} ->
        conn
        |> UserPlug.put_current_user(user.id)
        |> put_flash(:info, "Senha redefinida! Você já entrou como #{User.display_name(user)}.")
        |> redirect(to: ~p"/")

      {:error, :invalid_token} ->
        conn
        |> put_flash(:error, "Link inválido ou expirado. Pede um novo abaixo.")
        |> redirect(to: ~p"/entrar/esqueci")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, first_error_message(changeset))
        |> redirect(to: ~p"/entrar/nova-senha/#{token}")
    end
  end

  defp first_error_message(changeset) do
    case changeset.errors do
      [{field, {message, _}} | _] -> "#{field}: #{translate_message(message)}"
      _ -> "Não deu pra redefinir a senha. Confira os campos."
    end
  end

  defp translate_message(message) when is_binary(message) do
    cond do
      String.contains?(message, "should be at least") -> "mínimo 8 caracteres"
      String.contains?(message, "should be at most") -> "muito longa"
      true -> message
    end
  end

  # The source IP used to key the per-IP bucket. Prefers the
  # `x-forwarded-for` header first entry (Fly.io injects it) and falls
  # back to the socket peer. A malformed header collapses to `nil`
  # rather than crashing — the limiter buckets nil under "unknown".
  defp client_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [value | _] when is_binary(value) ->
        value |> String.split(",") |> List.first() |> String.trim()

      _ ->
        case conn.remote_ip do
          nil -> nil
          ip -> ip |> :inet.ntoa() |> to_string()
        end
    end
  end
end

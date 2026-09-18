defmodule RolezinhoWeb.AuthController do
  @moduledoc """
  GitHub OAuth flow (ADR-0002).

  Three actions:

    * `request/2` — kicked off by `Ueberauth` when the browser hits
      `GET /auth/github`. This controller is only reached in the failure
      branch of the plug pipeline; the success case redirects to GitHub
      directly. We keep the action here so a strategy without a working
      plug (typically, missing credentials) still returns a legible error
      to the visitor.

    * `callback/2` — GitHub redirects back here with a signed response.
      Ueberauth writes either `%Ueberauth.Auth{}` or `%Ueberauth.Failure{}`
      into `conn.assigns[:ueberauth_auth]` / `[:ueberauth_failure]` before
      this action runs. On success, we upsert the user, put the id in the
      session, and redirect to `return_to` (validated) or the home page.

    * `delete/2` — logout. Wipes the user id from the session and returns
      to the home page.
  """
  use RolezinhoWeb, :controller

  plug Ueberauth

  alias Rolezinho.Accounts
  alias Rolezinho.Accounts.User
  alias RolezinhoWeb.Plugs.User, as: UserPlug

  # ---------- request ----------

  # Reached only when Ueberauth itself couldn't start the flow (missing
  # provider configuration, for instance). The plug redirects on success.
  def request(conn, _params) do
    conn
    |> put_flash(:error, "Não deu pra iniciar o login com GitHub. Confere as configurações.")
    |> redirect(to: ~p"/")
  end

  # ---------- callback ----------

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Login com GitHub cancelado ou falhou. Tenta de novo.")
    |> redirect(to: ~p"/entrar")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, params) do
    attrs = auth_to_attrs(auth)

    case Accounts.find_or_create_by_github(attrs) do
      {:ok, %User{} = user} ->
        conn
        |> UserPlug.put_current_user(user.id)
        |> put_flash(:info, "Beleza, entrou como @#{user.github_login}.")
        |> redirect(to: safe_return_to(params["return_to"]))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Não deu pra salvar seu perfil. Tenta de novo.")
        |> redirect(to: ~p"/entrar")
    end
  end

  # ---------- logout ----------

  def delete(conn, _params) do
    conn
    |> UserPlug.clear_current_user()
    |> put_flash(:info, "Você saiu.")
    |> redirect(to: ~p"/")
  end

  # ---------- helpers ----------

  # Normalizes the Ueberauth response into the shape the Accounts context
  # expects (string keys mirroring the DB columns). Every field is optional
  # except `github_id` and `github_login`, which are needed to identify the
  # user across sign-ins.
  defp auth_to_attrs(%Ueberauth.Auth{} = auth) do
    info = auth.info || %Ueberauth.Auth.Info{}

    %{
      "github_id" => auth.uid,
      "github_login" => to_string(info.nickname || ""),
      "name" => info.name,
      "email" => info.email,
      "avatar_url" => info.image
    }
  end

  # An open-redirect gate. A `return_to` that isn't a same-origin path is
  # ignored: without this, an attacker could craft a `?return_to=https://evil`
  # to phish the user right after a genuine login. Only local paths starting
  # with `/` and not `//` (protocol-relative) are honored.
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
end

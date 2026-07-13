defmodule RolezinhoWeb.AdminSessionController do
  use RolezinhoWeb, :controller

  alias RolezinhoWeb.Plugs.Admin

  def new(conn, _params) do
    render(conn, :new, error: nil, page_title: "Login do admin")
  end

  def create(conn, %{"password" => password} = params) do
    if Admin.valid_password?(password) do
      return_to = Map.get(params, "return_to") || ~p"/admin"

      conn
      |> renew_session()
      |> put_session(:admin?, true)
      |> put_flash(:info, "Bem-vindo, admin!")
      |> redirect(to: return_to)
    else
      conn
      |> put_flash(:error, "Senha inválida.")
      |> put_status(:unauthorized)
      |> render(:new, error: "Senha inválida.", page_title: "Login do admin")
    end
  end

  def delete(conn, _params) do
    conn
    |> renew_session()
    |> put_flash(:info, "Você saiu.")
    |> redirect(to: ~p"/")
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end

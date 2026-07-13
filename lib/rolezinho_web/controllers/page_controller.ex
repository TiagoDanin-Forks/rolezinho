defmodule RolezinhoWeb.PageController do
  use RolezinhoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

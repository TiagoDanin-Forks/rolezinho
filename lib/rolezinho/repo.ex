defmodule Rolezinho.Repo do
  use Ecto.Repo,
    otp_app: :rolezinho,
    adapter: Ecto.Adapters.Postgres
end

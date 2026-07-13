defmodule Rolezinho.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    ensure_data_directories!()

    children = [
      RolezinhoWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:rolezinho, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Rolezinho.PubSub},
      # Start a worker by calling: Rolezinho.Worker.start_link(arg)
      # {Rolezinho.Worker, arg},
      # Start to serve requests, typically the last entry
      RolezinhoWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Rolezinho.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RolezinhoWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp ensure_data_directories! do
    base = Rolezinho.Events.data_path()
    File.mkdir_p!(base)
    File.mkdir_p!(Path.join(base, "hidden"))
    File.mkdir_p!(Path.join(base, "done"))
  end
end

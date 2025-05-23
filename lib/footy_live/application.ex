defmodule FootyLive.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FootyLiveWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:footy_live, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FootyLive.PubSub},
      # Start the Games cache
      FootyLive.Games,
      # Start the Realtime service
      FootyLive.Realtime,
      # Start to serve requests, typically the last entry
      FootyLiveWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FootyLive.Supervisor]

    # FootyLive.Database.initialise_disk_copies()
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FootyLiveWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

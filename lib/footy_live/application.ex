defmodule FootyLive.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :logger.add_handler(:foomtbal_sentry, Sentry.LoggerHandler, %{
      config: %{metadata: [:file, :line]}
    })

    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)

    File.mkdir_p!(Application.fetch_env!(:footy_live, :ets_path))

    children = [
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies) || [], [name: FootyLive.ClusterSupervisor]]},
      {NodeJS.Supervisor, [path: LiveSvelte.SSR.NodeJS.server_path(), pool_size: 4]},
      FootyLiveWeb.Telemetry,
      {Phoenix.PubSub, name: FootyLive.PubSub},
      # Start the Teams cache
      FootyLive.Teams,
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

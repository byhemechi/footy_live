defmodule FootyLive.MixProject do
  use Mix.Project

  def project do
    [
      app: :footy_live,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :dev,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {FootyLive.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:live_debugger, "~> 0.2", only: [:dev]},
      {:tidewave, "~> 0.1", only: [:dev]},
      {:igniter, "~> 0.5", only: [:dev, :test]},
      {:phoenix, "~> 1.8.0-rc.0", override: true},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:req, "~> 0.5"},
      {:mox, "~> 1.0", only: :test},
      {:server_sent_events, "~> 0.2"},
      {:sentry, "~> 11.0"},
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_exporter, "~> 1.0"},
      {:opentelemetry_semantic_conventions, "~> 1.27"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_bandit, "~> 0.1"},
      {:hackney, "~> 1.24"},
      {:live_svelte, "~> 0.16.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "cmd --cd assets npm ci"],
      "assets.build": ["tailwind footy_live", "cmd --cd assets node build.cjs"],
      "assets.deploy": [
        "tailwind footy_live --minify",
        "cmd --cd assets node build.cjs --deploy",
        "phx.digest"
      ]
    ]
  end
end

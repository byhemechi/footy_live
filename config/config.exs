# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :footy_live,
  generators: [timestamp_type: :utc_datetime],
  mix_env: Mix.env()

# Configures the endpoint
config :footy_live, FootyLiveWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: FootyLiveWeb.ErrorHTML, json: FootyLiveWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: FootyLive.PubSub,
  live_view: [signing_salt: "FiThRHrB"]

config :sentry,
  traces_sample_rate: 1.0

config :opentelemetry, span_processor: {Sentry.OpenTelemetry.SpanProcessor, []}
config :opentelemetry, sampler: {Sentry.OpenTelemetry.Sampler, []}

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  footy_live: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

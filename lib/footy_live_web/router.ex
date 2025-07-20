defmodule FootyLiveWeb.Router do
  use FootyLiveWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FootyLiveWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FootyLiveWeb do
    pipe_through :browser

    get "/healthz", HealthCheckController, :healthz
    live "/", LadderLive
    live "/games", GamesLive
    live "/teams", TeamsLive
    live "/teams/:team_id", TeamProfileLive

    live "/premiership_window", PremiershipWindowLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", FootyLiveWeb do
  #   pipe_through :api
  # end

    scope "/dev" do
      import Phoenix.LiveDashboard.Router

      pipe_through :browser

      live_dashboard "/dashboard", metrics: FootyLiveWeb.Telemetry
    end
end

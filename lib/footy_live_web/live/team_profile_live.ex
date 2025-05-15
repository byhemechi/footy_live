defmodule FootyLiveWeb.TeamProfileLive do
  use FootyLiveWeb, :live_view
  alias FootyLive.{Teams, Games}
  alias Squiggle.Team

  @impl true
  def mount(%{"team_id" => team_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(FootyLive.PubSub, "teams")
      Phoenix.PubSub.subscribe(FootyLive.PubSub, "games")
    end

    case Teams.get(team_id) do
      %Team{} = team ->
        games = Games.list_games_by_team(team_id)

        socket =
          socket
          |> assign(:page_title, team.name)
          |> assign(:team, team)
          |> stream(:games, games)

        {:ok, socket}

      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Team not found")
         |> redirect(to: ~p"/teams")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app {assigns}>
      <div class="space-y-8">
        <div class="flex items-center gap-4">
          <img src={"https://squiggle.com.au/#{@team.logo}"} alt="" class="w-16 h-16" />
          <h1 class="text-2xl font-bold">{@team.name}</h1>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div class="card">
            <h2 class="text-lg font-semibold mb-2">Team Info</h2>
            <dl class="space-y-1">
              <div class="flex gap-2">
                <dt class="font-medium">Abbreviation:</dt>
                <dd>{@team.abbrev}</dd>
              </div>
              <div class="flex gap-2">
                <dt class="font-medium">Debut Year:</dt>
                <dd>{@team.debut}</dd>
              </div>
              <%= if @team.retirement do %>
                <div class="flex gap-2">
                  <dt class="font-medium">Retired:</dt>
                  <dd>{@team.retirement}</dd>
                </div>
              <% end %>
            </dl>
          </div>
        </div>

        <div>
          <h2 class="text-lg font-semibold mb-4">Recent Games</h2>
          <div class="card  overflow-hidden">
            <.table id="games" rows={@streams.games}>
              <:col :let={{_id, game}} label="Round">
                {game.round}
              </:col>
              <:col :let={{_id, game}} label="Home">
                {game.hteam}
                <%= if game.complete do %>
                  ({game.hscore})
                <% end %>
              </:col>
              <:col :let={{_id, game}} label="Away">
                {game.ateam}
                <%= if game.complete do %>
                  ({game.ascore})
                <% end %>
              </:col>
              <:col :let={{_id, game}} label="Venue">
                {game.venue}
              </:col>
            </.table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_info({:games_updated, games}, socket) do
    team_id = socket.assigns.team.id
    team_games = Enum.filter(games, &(&1.hteamid == team_id || &1.ateamid == team_id))
    {:noreply, stream(socket, :games, team_games, reset: true)}
  end

  def handle_info({:teams_updated, teams}, socket) do
    team = Enum.find(teams, &(&1.id == socket.assigns.team.id))
    {:noreply, assign(socket, :team, team)}
  end
end

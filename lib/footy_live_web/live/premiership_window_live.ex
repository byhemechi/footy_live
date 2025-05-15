defmodule FootyLiveWeb.PremiershipWindowLive do
  alias Squiggle.{Game, Team}
  use FootyLiveWeb, :live_view
  @topic "games"

  def render(assigns) do
    ~H"""
    <Layouts.app {assigns}>
      <div class="flex-1 flex items-center justify-center">
        <div class="rounded-lg bg-base-200 p-8 relative card w-max">
          <div class="absolute bg-success/30 size-[calc(33%_+_var(--spacing)_*8)] rounded top-0 right-0" />
          <div class="w-96 h-96 relative">
            <img
              :for={team <- @teams}
              x={(@averages[team.id] |> elem(0)) - 1.5}
              y={(@averages[team.id] |> elem(1)) - 1.5}
              src={"https://squiggle.com.au/" <> team.logo}
              id={"badge-#{team.id}"}
              class="size-10 transition-all -translate-x-1/2 -translate-y-1/2 absolute bg-base-300 rounded-full object-contain p-1"
              style={
                [
                  "left: #{(elem(@averages[team.id], 0) - @min_for) / (@max_for - @min_for) * 100}%",
                  "top: #{(elem(@averages[team.id], 1) - @min_against) / (@max_against - @min_against) * 100}%"
                ]
                |> Enum.join(";")
              }
            />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @doc """
  Returns the score for a given team in a game. Returns zero if the team did not participate

  ## Examples

      iex> game = %Squiggle.Game{hteamid: 1, ateamid: 2, hscore: 100, ascore: 80, complete: 100}
      iex> FootyLiveWeb.PremiershipWindowLive.game_team_score(game, 1)
      {100, 100}
      iex> FootyLiveWeb.PremiershipWindowLive.game_team_score(game, 2)
      {80, 100}
      iex> FootyLiveWeb.PremiershipWindowLive.game_team_score(game, 4)
      {0, 0}
  """
  def game_team_score(%Game{} = game, team_id) do
    case game do
      %Game{hteamid: ^team_id, hscore: score, complete: complete} -> {score, complete}
      %Game{ateamid: ^team_id, ascore: score, complete: complete} -> {score, complete}
      _ -> {0, 0}
    end
  end

  def average_score_for(games, team_id, running_count \\ 0, total_games \\ 0)

  def average_score_for([%Game{} = head | tail], team_id, running_count, total_games) do
    {score, complete} = game_team_score(head, team_id)
    complete = complete / 100

    average_score_for(tail, team_id, running_count + score, total_games + complete)
  end

  def average_score_for([], _team_id, running_count, total_games) do
    running_count / total_games
  end

  def average_score_against(games, team_id, running_count \\ 0, total_games \\ 0)

  def average_score_against([%Game{} = head | tail], team_id, running_count, total_games) do
    other_team_id =
      case head do
        %Game{hteamid: ^team_id, ateamid: id} -> id
        %Game{ateamid: ^team_id, hteamid: id} -> id
        _ -> -1
      end

    {score, complete} = game_team_score(head, other_team_id)
    complete = complete / 100

    average_score_against(tail, team_id, running_count + score, total_games + complete)
  end

  def average_score_against([], _team_id, running_count, total_games) do
    running_count / total_games
  end

  def mount(_, _, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(FootyLive.PubSub, @topic)
    end

    teams = FootyLive.Teams.list_teams()
    games = FootyLive.Games.list_games()

    {:ok,
     socket
     |> assign(:teams, teams)
     |> calculate_and_assign_stats(teams, games)}
  end

  def handle_info({:games_updated, games}, socket) do
    teams = socket.assigns.teams
    {:noreply, calculate_and_assign_stats(socket, teams, games)}
  end

  defp calculate_and_assign_stats(socket, teams, games) do
    averages =
      for %Team{id: id} <- teams do
        {id, {games |> average_score_for(id), games |> average_score_against(id)}}
      end
      |> Enum.into(%{})

    max_for =
      averages |> Enum.reduce(0, fn {_id, {for, _against}}, current -> max(for, current) end)

    max_against =
      averages |> Enum.reduce(0, fn {_id, {_for, against}}, current -> max(against, current) end)

    min_for =
      averages
      |> Enum.reduce(:infinity, fn {_id, {for, _against}}, current -> min(for, current) end)

    min_against =
      averages
      |> Enum.reduce(:infinity, fn {_id, {_for, against}}, current -> min(against, current) end)

    socket
    |> assign(
      averages: averages,
      max_for: max_for,
      max_against: max_against,
      min_for: min_for,
      min_against: min_against
    )
  end
end

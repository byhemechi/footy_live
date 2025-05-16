defmodule FootyLiveWeb.PremiershipWindowLive do
  alias Squiggle.{Game, Team}
  use FootyLiveWeb, :live_view
  @topic "games"

  def render(assigns) do
    ~H"""
    <Layouts.app {assigns}>
      <div class="size-[calc(min(100dvh_-_var(--spacing)_*_20,_100dvw))] m-auto p-4">
        <div
          class="rounded-lg grid bg-base-200 relative card size-full gap-1.5 p-4"
          style="grid-template-rows: auto 1.5em 1.5em; grid-template-columns: 1.5em 1.5em auto;"
        >
          <div class="text-base-content/80 font-semibold row-start-3 col-start-3 text-center">
            Average Goals For
          </div>
          <div class="text-base-content/80 font-semibold row-start-1 col-start-1 text-center rotate-180 [writing-mode:vertical-rl]">
            Average Goals Against
          </div>

          <div class="col-start-3 row-start-2 relative">
            <div
              :for={n <- @start_for..@end_for//5}
              :if={n > @start_for && n < @end_for}
              }
              id={"tick-x-#{n}"}
              class="-translate-x-1/2 bottom-0 text-base-content/30 absolute transition-all"
              style={ "left: #{(n - @start_for) / (@end_for - @start_for) * 100}%"}
            >
              {n}
            </div>
          </div>
          <div class="row-start-1 col-start-2 relative">
            <div
              :for={n <- @start_against..@end_against//5}
              :if={n > @start_against && n < @end_against}
              id={"tick-y-#{n}"}
              class="right-0 transition-all [writing-mode:vertical-lr] rotate-180 -translate-y-1/2 text-base-content/30 absolute"
              style={ "top: #{(n - @start_against) / (@end_against - @start_against) * 100}%"}
            >
              {n}
            </div>
          </div>
          <div class="w-full h-full relative row-start-1 col-start-3 border-base-300 border overflow-hidden bg-base-100 rounded-lg">
            <div
              :for={n <- @start_for..@end_for//5}
              :if={n > @start_for && n < @end_for}
              class="w-px h-full bg-base-300 absolute transition-all"
              id={"line-x-#{n}"}
              style={ "left: #{(n - @start_for) / (@end_for - @start_for) * 100}%"}
            />
            <div
              :for={n <- @start_against..@end_against//5}
              :if={n > @start_against && n < @end_against}
              class="h-px w-full bg-base-300 absolute transition-all"
              id={"line-y-#{n}"}
              style={ "top: #{(n - @start_against) / (@end_against - @start_against) * 100}%"}
            />

            <div class="absolute bg-success/10 size-1/3 top-0 right-0 grid place-content-center text-success/50" />
            <div class="absolute bg-error/10 size-1/3 bottom-0 left-0 text-error/50 grid place-content-center" />
            <img
              :for={team <- @teams}
              x={(@averages[team.id] |> elem(0)) - 1.5}
              y={(@averages[team.id] |> elem(1)) - 1.5}
              src={"https://live.squiggle.com.au/" <> team.name <> ".png"}
              id={"badge-#{team.id}"}
              class="size-10 transition-all -translate-x-1/2 -translate-y-1/2 absolute bg-base-300 shadow rounded-full object-cover"
              style={
                [
                  "left: #{(elem(@averages[team.id], 0) - @start_for) / (@end_for - @start_for) * 100}%",
                  "top: #{(elem(@averages[team.id], 1) - @start_against) / (@end_against - @start_against) * 100}%"
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
     |> assign(:route, :premiership_window)
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
      min_against: min_against,
      start_for: floor(min_for / 5) * 5 - 5,
      end_for: ceil(max_for / 5) * 5 + 5,
      start_against: floor(min_against / 5) * 5 - 5,
      end_against: ceil(max_against / 5) * 5 + 5
    )
  end
end

defmodule FootyLiveWeb.PremiershipWindowLive do
  alias Squiggle.{Game, Team}
  use FootyLiveWeb, :live_view

  def render(assigns) do
    ~H"""
    <svg
      class="h-screen bg-base-200"
      viewbox={"#{@min_for} #{@min_against} #{@max_for - @min_for} #{@max_against - @min_against}"}
    >
      <rect
        x={@min_for + (@max_for - @min_for) * 2 / 3}
        y={@min_against}
        width={200}
        height={(@max_against - @min_against) / 3}
        class="fill-success/30"
      />
      <image
        :for={team <- @teams}
        x={(@averages[team.id] |> elem(0)) - 1.5}
        y={(@averages[team.id] |> elem(1)) - 1.5}
        href={"https://squiggle.com.au/" <> team.logo}
        width="3"
        height="3"
      />
    </svg>
    <.table rows={@teams} id="matrix">
      <:col :let={team} label="Name">{team.name}</:col>
      <:col :let={team} label="Average score for">
        {@averages[team.id] |> elem(0) |> :erlang.float_to_binary(decimals: 2)}
      </:col>
      <:col :let={team} label="Average score against">
        {@averages[team.id] |> elem(1) |> :erlang.float_to_binary(decimals: 2)}
      </:col>
      <:col :let={team} label="Percentage">
        {((@averages[team.id] |> elem(0)) / (@averages[team.id] |> elem(1)) * 100)
        |> :erlang.float_to_binary(decimals: 2)}
      </:col>
    </.table>
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
    teams = FootyLive.Teams.list_teams()
    games = FootyLive.Games.list_games()

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

    {:ok,
     socket
     |> assign(
       averages: averages,
       teams: teams,
       max_for: max_for,
       max_against: max_against,
       min_for: min_for,
       min_against: min_against
     )}
  end
end

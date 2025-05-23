defmodule FootyLive.Games do
  @moduledoc """
  Context for managing AFL games and their cached data.
  """
  require Logger

  use GenServer

  @topic "games"
  @realtime_topic "live_games"
  @refresh_interval :timer.hours(1)

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns the list of all games.
  """
  @spec list_games(filter :: list(tuple) | tuple) :: [Squiggle.Game.t()]
  def list_games(filter) do
    Memento.transaction!(fn ->
      Memento.Query.select(Squiggle.Game, filter)
    end)
  end

  def list_games do
    Memento.transaction!(fn -> Memento.Query.all(Squiggle.Game) end)
    |> case do
      [] ->
        refresh()

      games ->
        games
    end
  end

  @doc """
  Returns the list of games for a specific team.
  """
  def list_games_by_team(team_id) when is_integer(team_id) do
    Memento.transaction!(fn ->
      Memento.Query.select(
        Squiggle.Game,
        {:or, {:==, :hteamid, team_id}, {:==, :ateamid, team_id}}
      )
    end)
  end

  def list_games_by_team(team_id) when is_binary(team_id) do
    case Integer.parse(team_id) do
      {id, _} -> list_games_by_team(id)
      :error -> []
    end
  end

  def list_games_by_team(_), do: []

  @doc """
  Returns the list of games for a specific round.
  """
  def list_games_by_round(round, year \\ DateTime.utc_now().year)

  def list_games_by_round(round, year) when is_integer(round) do
    list_games(round: round, year: year)
  end

  def list_games_by_round(round, year) when is_binary(round) do
    case Integer.parse(round) do
      {num, _} -> list_games_by_round(num, year)
      :error -> []
    end
  end

  def list_games_by_round(_round, _year), do: []

  @doc """
  Returns a game by its ID.
  """
  def get_game(id) when is_integer(id) do
    Memento.transaction!(fn ->
      Memento.Query.read(Squiggle.Game, id)
    end)
  end

  def get_game(id) when is_binary(id) do
    case Integer.parse(id) do
      {num, _} -> get_game(num)
      :error -> nil
    end
  end

  def get_game(_), do: nil

  @doc """
  Stores a single game in the cache and broadcasts the update.
  """
  def put_game(%Squiggle.Game{} = game) do
    Memento.transaction!(fn ->
      Memento.Query.write(game)
    end)

    Phoenix.PubSub.broadcast(FootyLive.PubSub, @realtime_topic, {:game_updated, game})

    Task.start(fn ->
      sorted_games = list_games()
      Phoenix.PubSub.broadcast(FootyLive.PubSub, @topic, {:games_updated, sorted_games})
    end)

    game
  end

  def put_game(game) when is_map(game) do
    put_game(struct(Squiggle.Game, game))
  end

  def put_game(_), do: nil

  @doc """
  Stores multiple games in the cache and broadcasts the update.
  """
  def put_games(games) when is_list(games) do
    games =
      games
      |> Enum.map(fn
        %Squiggle.Game{} = game -> game
        game when is_map(game) -> struct(Squiggle.Game, game)
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    Memento.transaction!(fn ->
      for game <- games do
        Memento.Query.write(game)
      end
    end)

    sorted_games = list_games()
    Phoenix.PubSub.broadcast(FootyLive.PubSub, @topic, {:games_updated, sorted_games})
    games
  end

  def put_games(_), do: []

  @doc """
  Returns a sorted list of all available rounds.
  """
  def list_rounds(year \\ DateTime.utc_now().year) do
    list_games()
    |> Enum.filter(&(&1.year == year))
    |> Enum.map(
      &%__MODULE__.Round{
        kind:
          case &1.is_final do
            0 -> :home_and_away
            final when final in 1..5 -> :final
            6 -> :grand_final
          end,
        id: &1.round
      }
    )
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Returns a sorted list of all available years.
  """
  def list_years do
    list_games()
    |> Enum.map(& &1.year)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @impl true
  def init(opts) do
    Memento.Table.wait([Squiggle.Game], :infinity)
    timer = schedule_refresh()

    {:ok, %{timer: timer, name: opts[:name]}}
  end

  @impl true
  def handle_info(:refresh, state) do
    refresh()
    timer = schedule_refresh()
    {:noreply, %{state | timer: timer}}
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  @doc """
  Manually refresh the games cache.
  """
  def refresh(year \\ DateTime.utc_now().year) do
    case Squiggle.games(year: year) do
      {:ok, %{games: games}} ->
        games =
          games
          |> Enum.map(&struct(Squiggle.Game, &1))

        put_games(games)

      {:error, _} ->
        []
    end
  end
end

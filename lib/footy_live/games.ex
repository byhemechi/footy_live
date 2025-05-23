defmodule FootyLive.Games do
  @moduledoc """
  Context for managing AFL games and their cached data.
  """
  alias Squiggle.Game

  use GenServer

  @default_table_name "afl_games"
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
  def list_games(filter) when is_list(filter) do
    list_games()
    |> Enum.filter(fn game ->
      for {k, v} <- filter do
        match?(%{^k => ^v}, game)
      end
      |> Enum.reduce(true, &(&1 && &2))
    end)
  end

  def list_games do
    case :dets.select(table_name(), [{:"$1", [], [:"$1"]}]) do
      [] ->
        refresh()

      games ->
        games
        |> Enum.map(&elem(&1, 1))
        |> Enum.sort_by(& &1.date)
    end
  end

  @doc """
  Returns the list of games for a specific team.
  """
  def list_games_by_team(team_id) when is_integer(team_id) do
    list_games()
    |> Enum.filter(fn game ->
      game.hteamid == team_id || game.ateamid == team_id
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
    case :dets.lookup(table_name(), id) do
      [{^id, game}] -> game
      [] -> nil
    end
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
    :dets.insert(table_name(), {game.id, game})
    sorted_games = list_games()
    Phoenix.PubSub.broadcast(FootyLive.PubSub, @topic, {:games_updated, sorted_games})
    Phoenix.PubSub.broadcast(FootyLive.PubSub, @realtime_topic, {:game_updated, game})
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

    for game <- games do
      :dets.insert(table_name(), {game.id, game})
    end

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

  @doc """
  Manually refresh the games cache.
  """
  def refresh(year \\ DateTime.utc_now().year) do
    GenServer.call(__MODULE__, {:refresh, year})
  end

  # Server

  @impl true
  def init(opts) do
    table_name = table_name(opts)
    path = Path.join(Application.fetch_env!(:footy_live, :dets_path), "#{table_name}.dets")
    File.mkdir_p!(Path.dirname(path))
    {:ok, table} = :dets.open_file(table_name, file: String.to_charlist(path), type: :set)
    timer = schedule_refresh()
    do_refresh()

    {:ok, %{table: table, timer: timer, name: opts[:name]}}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    games = do_refresh()
    {:reply, games, state}
  end

  @impl true
  def handle_call({:refresh, year}, _from, state) do
    games = do_refresh(year)
    {:reply, games, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    do_refresh()
    timer = schedule_refresh()
    {:noreply, %{state | timer: timer}}
  end

  @impl true
  def terminate(_reason, %{table: table, timer: timer}) do
    if timer, do: Process.cancel_timer(timer)
    :dets.close(table)
    :ok
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp table_name(opts \\ []) do
    case opts[:name] do
      nil -> @default_table_name
      name when is_atom(name) -> "#{name}_table"
    end
    |> String.to_atom()
  end

  defp do_refresh(year \\ DateTime.utc_now().year) do
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

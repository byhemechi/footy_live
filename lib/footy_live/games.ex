defmodule FootyLive.Games do
  @moduledoc """
  Context for managing AFL games and their cached data.
  """

  use GenServer

  @topic "games"
  @realtime_topic "live_games"
  @refresh_interval :timer.hours(1)

  require OpenTelemetry.Tracer, as: Tracer

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
    case :ets.select(__MODULE__, [{:"$1", [], [:"$1"]}]) do
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
    case :ets.lookup(__MODULE__, id) do
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

  def put_game(game) do
    GenServer.call(__MODULE__, {:put_game, game})
  end

  defp do_put_game(%Squiggle.Game{} = game) do
    :ets.insert(__MODULE__, {game.id, game})
    sorted_games = list_games()
    Phoenix.PubSub.broadcast(FootyLive.PubSub, @topic, {:games_updated, sorted_games})
    Phoenix.PubSub.broadcast(FootyLive.PubSub, @realtime_topic, {:game_updated, game})
    game
  end

  defp do_put_game(game) when is_map(game) do
    do_put_game(struct(Squiggle.Game, game))
  end

  defp do_put_game(_), do: nil

  @doc """
  Stores multiple games in the cache and broadcasts the update.
  """
  def put_games(games) do
    GenServer.call(__MODULE__, {:put_games, games})
  end

  defp do_put_games(games) when is_list(games) do
    games =
      games
      |> Enum.map(fn
        %Squiggle.Game{} = game -> game
        game when is_map(game) -> struct(Squiggle.Game, game)
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    for game <- games do
      :ets.insert(__MODULE__, {game.id, game})
    end

    save_changes()

    sorted_games = list_games()
    Phoenix.PubSub.broadcast(FootyLive.PubSub, @topic, {:games_updated, sorted_games})
    games
  end

  defp do_put_games(_), do: []

  @doc """
  Returns a sorted list of all available rounds.
  """
  def list_rounds(opts \\ [])

  def list_rounds(year) when is_integer(year), do: list_rounds(year: year)

  def list_rounds(opts) when is_list(opts) do
    Tracer.with_span "list_rounds" do
      year = Keyword.get(opts, :year, DateTime.utc_now().year)
      hide_future = Keyword.get(opts, :hide_future, false)

      list_games()
      |> Enum.filter(&(&1.year == year))
      |> Enum.filter(fn
        %Squiggle.Game{complete: 0} when hide_future -> false
        %Squiggle.Game{complete: _} -> true
      end)
      |> Enum.map(&__MODULE__.Round.from_game/1)
      |> Enum.uniq()
      |> Enum.sort()
    end
  end

  def current_round do
    list_games()
    |> Enum.find(&(&1.complete !== 100))
    |> __MODULE__.Round.from_game()
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

  defp get_path do
    Path.join(Application.fetch_env!(:footy_live, :ets_path), "#{__MODULE__}.ets")
  end

  defp save_changes do
    :ets.tab2file(__MODULE__, String.to_charlist(get_path()))
  end

  @impl true
  def init(opts) do
    table =
      case :ets.file2tab(String.to_charlist(get_path())) do
        {:ok, table} ->
          table

        {:error, {:read_error, {:file_error, _path, :enoent}}} ->
          :ets.new(__MODULE__, [:set, :protected, :named_table])

        {:error, err} ->
          raise err
      end

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
  def handle_call({:put_game, game}, _from, state) do
    {:reply, do_put_game(game), state}
  end

  @impl true
  def handle_call({:put_games, games}, _from, state) do
    {:reply, do_put_games(games), state}
  end

  @impl true
  def handle_cast({:put_game, game}, state) do
    do_put_game(game)
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    do_refresh()
    timer = schedule_refresh()
    {:noreply, %{state | timer: timer}}
  end

  @impl true
  def terminate(_reason, %{timer: timer}) do
    if timer, do: Process.cancel_timer(timer)

    save_changes()
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp do_refresh(year \\ DateTime.utc_now().year) do
    Tracer.with_span "refresh_games" do
      case Squiggle.games(year: year) do
        {:ok, %{games: games}} ->
          games =
            games
            |> Enum.map(&struct(Squiggle.Game, &1))

          do_put_games(games)

        {:error, _} ->
          []
      end
    end
  end
end

defmodule FootyLive.Games do
  @moduledoc """
  Context for managing AFL games and their cached data.
  """

  use GenServer

  @default_table_name :afl_games
  @topic "games"
  @refresh_interval :timer.hours(1)

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns the list of all games.
  """
  def list_games do
    case :ets.tab2list(table_name()) do
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
  def list_games_by_round(round) when is_integer(round) do
    list_games()
    |> Enum.filter(fn game -> game.round == round end)
  end

  def list_games_by_round(round) when is_binary(round) do
    case Integer.parse(round) do
      {num, _} -> list_games_by_round(num)
      :error -> []
    end
  end

  def list_games_by_round(_), do: []

  @doc """
  Returns a sorted list of all available rounds.
  """
  def list_rounds do
    list_games()
    |> Enum.map(& &1.round)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Manually refresh the games cache.
  """
  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  # Server

  @impl true
  def init(opts) do
    table_name = table_name(opts)
    table = :ets.new(table_name, [:set, :named_table, :public, read_concurrency: true])
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
  def handle_info(:refresh, state) do
    do_refresh()
    timer = schedule_refresh()
    {:noreply, %{state | timer: timer}}
  end

  @impl true
  def terminate(_reason, %{timer: timer}) do
    if timer, do: Process.cancel_timer(timer)
    :ok
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp table_name(opts \\ []) do
    case opts[:name] do
      nil -> @default_table_name
      name when is_atom(name) -> :"#{name}_table"
    end
  end

  defp do_refresh do
    case Squiggle.games(year: DateTime.utc_now().year) do
      {:ok, %{games: games}} ->
        games =
          games
          |> Enum.map(&struct(Squiggle.Game, &1))

        games
        |> Enum.each(fn game ->
          :ets.insert(table_name(), {game.id, game})
        end)

        sorted_games = Enum.sort_by(games, & &1.date)
        Phoenix.PubSub.broadcast(FootyLive.PubSub, @topic, {:games_updated, sorted_games})
        sorted_games

      {:error, _} ->
        []
    end
  end
end

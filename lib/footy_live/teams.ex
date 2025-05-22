defmodule FootyLive.Teams do
  @moduledoc """
  Context for managing AFL teams and their cached data.
  """

  use GenServer

  @default_table_name "afl_teams"
  @topic "teams"

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Get a team's name by ID.
  """
  def name(team_id) when is_integer(team_id) do
    case :dets.lookup(table_name(), team_id) do
      [{^team_id, team}] -> team.name
      [] -> "Unknown"
    end
  end

  def name(team_id) when is_binary(team_id) do
    case Integer.parse(team_id) do
      {id, _} -> name(id)
      :error -> "Unknown"
    end
  end

  def name(_), do: "Unknown"

  @doc """
  Get a team by ID.
  """
  def get(team_id) when is_integer(team_id) do
    case :dets.lookup(table_name(), team_id) do
      [{^team_id, team}] -> team
      [] -> nil
    end
  end

  def get(team_id) when is_binary(team_id) do
    case Integer.parse(team_id) do
      {id, _} -> get(id)
      :error -> nil
    end
  end

  def get(_), do: nil

  @doc """
  Returns the list of all teams.
  """
  def list_teams do
    case :dets.select(table_name(), [{:"$1", [], [:"$1"]}]) do
      [] ->
        refresh()

      teams ->
        teams
        |> Enum.map(&elem(&1, 1))
        |> Enum.sort_by(& &1.name)
    end
  end

  @doc """
  Manually refresh the teams cache.
  """
  def refresh do
    GenServer.call(__MODULE__, :refresh)
  end

  # Server

  @impl true
  def init(opts) do
    table_name = table_name(opts)
    path = Path.join(Application.fetch_env!(:footy_live, :dets_path), "#{table_name}.dets")
    File.mkdir_p!(Path.dirname(path))
    {:ok, table} = :dets.open_file(table_name, file: String.to_charlist(path), type: :set)

    {:ok, %{table: table, timer: nil, name: opts[:name]}}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    teams = do_refresh()
    {:reply, teams, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    do_refresh()
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{table: table}) do
    :dets.close(table)
    :ok
  end

  defp table_name(opts \\ []) do
    case opts[:name] do
      nil -> @default_table_name
      name when is_atom(name) -> "#{name}_table"
    end
    |> String.to_atom()
  end

  defp do_refresh do
    case Squiggle.teams() do
      {:ok, %{teams: teams}} ->
        teams
        |> Enum.map(&struct(Squiggle.Team, &1))
        |> Enum.each(fn team ->
          :dets.insert(table_name(), {team.id, team})
        end)

        sorted_teams = Enum.sort_by(teams, & &1.name)
        Phoenix.PubSub.broadcast(FootyLive.PubSub, @topic, {:teams_updated, sorted_teams})
        sorted_teams

      {:error, _} ->
        []
    end
  end
end

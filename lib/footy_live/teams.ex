defmodule FootyLive.Teams do
  @moduledoc """
  Context for managing AFL teams and their cached data.
  """

  use GenServer

  @topic "teams"

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Get a team's name by ID.
  """
  def name(team_id) when is_integer(team_id) do
    case :ets.lookup(__MODULE__, team_id) do
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
    case :ets.lookup(__MODULE__, team_id) do
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
    case :ets.select(__MODULE__, [{:"$1", [], [:"$1"]}]) do
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

  defp get_path do
    Path.join(Application.fetch_env!(:footy_live, :ets_path), "#{__MODULE__}.ets")
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
    save_changes()
  end

  defp save_changes do
    :ets.tab2file(__MODULE__, String.to_charlist(get_path()))
  end

  defp do_refresh do
    case Squiggle.teams() do
      {:ok, %{teams: teams}} ->
        teams
        |> Enum.map(&struct(Squiggle.Team, &1))
        |> Enum.each(fn team ->
          :ets.insert(__MODULE__, {team.id, team})
        end)

        sorted_teams = Enum.sort_by(teams, & &1.name)
        Phoenix.PubSub.broadcast(FootyLive.PubSub, @topic, {:teams_updated, sorted_teams})

        sorted_teams

      {:error, _} ->
        []
    end
  end
end

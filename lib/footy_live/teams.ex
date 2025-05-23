defmodule FootyLive.Teams do
  @moduledoc """
  Context for managing AFL teams and their cached data.
  """

  @topic "teams"
  require Logger

  @doc """
  Get a team by ID.
  """
  def get(team_id) when is_integer(team_id) do
    Memento.transaction!(fn ->
      Memento.Query.read(Squiggle.Team, team_id)
    end)
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
    Memento.transaction!(fn -> Memento.Query.all(Squiggle.Team) end)
    |> case do
      [] ->
        refresh()

      teams ->
        teams
    end
  end

  def refresh do
    Logger.info("Refreshing teams...")

    case Squiggle.teams() do
      {:ok, %{teams: teams}} ->
        teams =
          Enum.map(teams, &struct(Squiggle.Team, &1))

        Memento.transaction!(fn ->
          teams
          |> Enum.each(fn team ->
            Memento.Query.write(team)
          end)
        end)

        Phoenix.PubSub.broadcast(FootyLive.PubSub, @topic, {:teams_updated, teams})
        teams

      {:error, _} ->
        []
    end
  end
end

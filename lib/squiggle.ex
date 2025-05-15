defmodule Squiggle do
  @moduledoc """
  A client for the Squiggle API (api.squiggle.au)

  The Squiggle API offers public access to basic data (fixture, ladder, match scores) on AFL games,
  plus predictions made by computer models.

  ## Examples
      # Get all teams
      {:ok, teams} = Squiggle.get(query: :teams)

      # Get games for a specific year and round
      {:ok, games} = Squiggle.get(query: :games, year: 2024, round: 1)

      # Get ladders in CSV format
      {:ok, csv} = Squiggle.get(query: :ladder, format: :csv)
  """

  @base_url "https://api.squiggle.au"
  @user_agent "Elixir FootyLive -@byhemechi on twitter"

  @type query ::
          :teams
          | :games
          | :sources
          | :tips
          | :standings
          | :ladder
          | :power

  @type query_param ::
          {:year, non_neg_integer()}
          | {:round, String.t() | non_neg_integer()}
          | {:game, pos_integer()}
          | {:team, pos_integer()}
          | {:source, pos_integer()}
          | {:complete, 0..100}
          | {:live, boolean()}
          | {:dummy, boolean()}

  @type format :: :json | :xml | :csv
  @type params :: [{:format, format()} | query_param()]
  @type error :: {:error, Exception.t() | String.t()}
  @type result :: {:ok, map() | String.t()} | error()

  defguardp is_query(q)
            when q in [:teams, :games, :sources, :tips, :standings, :ladder, :power]

  defguardp is_format(f) when f in [:json, :xml, :csv]

  @doc """
  Creates a new Req instance with the base URL and user agent preconfigured.
  """
  def new(opts \\ []) do
    req_client().new(
      base_url: @base_url,
      user_agent: @user_agent,
      decode_json: [keys: :atoms]
    )
    |> then(&req_client().merge(&1, opts))
  end

  @doc """
  Makes a request to the Squiggle API.

  ## Options

  * `:query` - Required. The type of query to make (`:teams`, `:games`, etc)
  * `:format` - Optional. The format to return (`:json`, `:xml`, `:csv`). Defaults to `:json`
  * Additional options are passed as query parameters to the API

  ## Examples
      # All teams
      {:ok, %{teams: teams}} = Squiggle.get(query: :teams)

      # Games from Round 1, 2024
      {:ok, %{games: games}} = Squiggle.get(query: :games, year: 2024, round: 1)

      # Get tips in CSV format
      {:ok, csv} = Squiggle.get(query: :tips, format: :csv)
  """
  @spec get([{:query, query()} | {:format, format()} | query_param()]) :: result()
  def get(opts) when is_list(opts) do
    with {:ok, _query} <- fetch_required_query(opts),
         {:ok, params} <- build_params(opts) do
      new()
      |> req_client().get(url: "/", params: params)
      |> case do
        {:ok, %{status: 200} = resp} -> {:ok, resp.body}
        {:ok, resp} -> {:error, "Unexpected response: #{resp.status}"}
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Same as `get/1` but raises on error.
  """
  @spec get!([{:query, query()} | {:format, format()} | query_param()]) :: map() | String.t()
  def get!(opts) do
    case get(opts) do
      {:ok, result} -> result
      {:error, error} -> raise "Squiggle API error: #{inspect(error)}"
    end
  end

  @doc """
  Get info about AFL teams.

  ## Options

  * `:team` - Optional. Filter by team ID
  * `:year` - Optional. Filter by year
  * `:format` - Optional. Response format (`:json`, `:xml`, `:csv`)

  ## Examples
      # Get all teams
      {:ok, %{teams: teams}} = Squiggle.teams()

      # Get a specific team
      {:ok, %{teams: [team]}} = Squiggle.teams(team: 1)
  """
  @spec teams(params()) :: result()
  def teams(opts \\ []), do: get([{:query, :teams} | opts])

  @doc """
  Get info about games.

  ## Options

  * `:year` - Optional. Filter by year
  * `:round` - Optional. Filter by round
  * `:game` - Optional. Filter by game ID
  * `:team` - Optional. Filter by team ID
  * `:complete` - Optional. Filter by completion percentage (0-100)
  * `:live` - Optional. Filter by live status
  * `:format` - Optional. Response format (`:json`, `:xml`, `:csv`)

  ## Examples
      # Get games from a specific round
      {:ok, %{games: games}} = Squiggle.games(year: 2024, round: 1)

      # Get live games
      {:ok, %{games: live_games}} = Squiggle.games(live: true)
  """
  @spec games(params()) :: result()
  def games(opts \\ []), do: get([{:query, :games} | opts])

  @doc """
  Get info about computer models/sources.

  ## Options

  * `:source` - Optional. Filter by source ID
  * `:format` - Optional. Response format (`:json`, `:xml`, `:csv`)

  ## Examples
      # Get all sources
      {:ok, %{sources: sources}} = Squiggle.sources()

      # Get a specific source
      {:ok, %{sources: [source]}} = Squiggle.sources(source: 1)
  """
  @spec sources(params()) :: result()
  def sources(opts \\ []), do: get([{:query, :sources} | opts])

  @doc """
  Get tips made by computer models.

  ## Options

  * `:year` - Optional. Filter by year
  * `:round` - Optional. Filter by round
  * `:game` - Optional. Filter by game ID
  * `:source` - Optional. Filter by source ID
  * `:team` - Optional. Filter by team ID
  * `:complete` - Optional. Filter by completion percentage (0-100)
  * `:format` - Optional. Response format (`:json`, `:xml`, `:csv`)

  ## Examples
      # Get tips for a round
      {:ok, %{tips: tips}} = Squiggle.tips(year: 2024, round: 1)

      # Get tips from a specific source
      {:ok, %{tips: source_tips}} = Squiggle.tips(source: 1)
  """
  @spec tips(params()) :: result()
  def tips(opts \\ []), do: get([{:query, :tips} | opts])

  @doc """
  Get team standings (ladder) at a point in time.

  ## Options

  * `:year` - Optional. Filter by year
  * `:round` - Optional. Filter by round
  * `:format` - Optional. Response format (`:json`, `:xml`, `:csv`)

  ## Examples
      # Get current standings
      {:ok, %{standings: standings}} = Squiggle.standings()

      # Get standings after Round 1, 2024
      {:ok, %{standings: standings}} = Squiggle.standings(year: 2024, round: 1)
  """
  @spec standings(params()) :: result()
  def standings(opts \\ []), do: get([{:query, :standings} | opts])

  @doc """
  Get projected ladders generated by computer models.

  ## Options

  * `:year` - Optional. Filter by year
  * `:round` - Optional. Filter by round
  * `:source` - Optional. Filter by source ID
  * `:dummy` - Optional. Flag for placeholder data
  * `:format` - Optional. Response format (`:json`, `:xml`, `:csv`)

  ## Examples
      # Get projected ladder
      {:ok, %{ladder: ladder}} = Squiggle.ladder(year: 2024, round: 1)

      # Get projected ladder from a specific source
      {:ok, %{ladder: source_ladder}} = Squiggle.ladder(source: 1)
  """
  @spec ladder(params()) :: result()
  def ladder(opts \\ []), do: get([{:query, :ladder} | opts])

  @doc """
  Get power rankings generated by computer models.

  ## Options

  * `:year` - Optional. Filter by year
  * `:round` - Optional. Filter by round
  * `:source` - Optional. Filter by source ID
  * `:team` - Optional. Filter by team ID
  * `:dummy` - Optional. Flag for placeholder data
  * `:format` - Optional. Response format (`:json`, `:xml`, `:csv`)

  ## Examples
      # Get power rankings
      {:ok, %{power: rankings}} = Squiggle.power(year: 2024, round: 1)

      # Get power rankings for a specific team from a source
      {:ok, %{power: team_rankings}} = Squiggle.power(source: 1, team: 1)
  """
  @spec power(params()) :: result()
  def power(opts \\ []), do: get([{:query, :power} | opts])

  # Private helpers

  defp fetch_required_query(opts) do
    case Keyword.fetch(opts, :query) do
      {:ok, q} when is_query(q) -> {:ok, q}
      {:ok, other} -> {:error, "Invalid query type: #{inspect(other)}"}
      :error -> {:error, "Missing required :query option"}
    end
  end

  defp build_params(opts) do
    params = [q: Keyword.fetch!(opts, :query)]

    params =
      case Keyword.get(opts, :format) do
        nil -> params
        f when is_format(f) -> [{:format, f} | params]
        other -> throw({:error, "Invalid format: #{inspect(other)}"})
      end

    params =
      opts
      |> Keyword.drop([:query, :format])
      |> Enum.reduce(params, fn
        {k, v}, acc when k in [:year, :round, :game, :team, :source, :complete] ->
          [{k, v} | acc]

        {k, v}, acc when k in [:live, :dummy] ->
          [{k, if(v, do: 1, else: 0)} | acc]

        {k, _}, _acc ->
          throw({:error, "Invalid parameter: #{inspect(k)}"})
      end)

    {:ok, params}
  catch
    {:error, _} = error -> error
  end

  defp req_client do
    Application.get_env(:footy_live, :req_client, Req)
  end
end

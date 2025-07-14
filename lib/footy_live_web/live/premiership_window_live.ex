defmodule FootyLiveWeb.PremiershipWindowLive do
  alias Squiggle.{Game, Team}
  use FootyLiveWeb, :live_view
  import FootyLiveWeb.Team
  @topic "live_games"

  require OpenTelemetry.Tracer, as: Tracer

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} route={:premiership_window}>
      <div class="w-full max-w-screen-lg h-[calc(min(100dvh_-_var(--spacing)_*_20,_100dvw))] m-auto p-4">
        <div
          class="rounded-lg grid bg-base-200 relative card size-full gap-1.5 p-4"
          style="grid-template-rows: auto 1.5em 1.5em; grid-template-columns: 1.5em 1.5em auto;"
        >
          <div class="text-base-content/80 font-semibold row-start-3 col-start-3 text-center">
            Average Points For
          </div>
          <div class="text-base-content/80 font-semibold row-start-1 col-start-1 text-center rotate-180 [writing-mode:vertical-rl]">
            Average Points Against
          </div>

          <div class="col-start-3 row-start-2 relative">
            <div
              :for={n <- @start_for..@end_for//5}
              :if={n > @start_for && n < @end_for}
              }
              id={"tick-x-#{n}"}
              class={[
                "-translate-x-1/2 bottom-0 text-base-content/30 absolute transition-all",
                rem(n, 10) > 0 && "hidden min-[350px]:block"
              ]}
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
              class={[
                "right-0 transition-all [writing-mode:vertical-lr] rotate-180 -translate-y-1/2 text-base-content/30 absolute",
                rem(n, 10) > 0 && "hidden min-[350px]:block"
              ]}
              style={ "top: #{(n - @start_against) / (@end_against - @start_against) * 100}%"}
            >
              {n}
            </div>
          </div>
          <div class="w-full h-full relative row-start-1 col-start-3 border-base-300 border overflow-hidden bg-base-100 rounded-lg isolate">
            <svg
              class="size-full absolute inset-0"
              preserveAspectRatio="none"
              viewbox="0 0 1 1"
              xmlns="http://www.w3.org/2000/svg"
            >
              <defs>
                <% scale_x = (@end_for - @start_for) / 5
                scale_y = (@end_against - @start_against) / 5
                translate_x = @start_for / 5
                translate_y = @start_against / 5 %>

                <pattern
                  id="grid"
                  width="1"
                  height="1"
                  patternUnits="userSpaceOnUse"
                  patternTransform={"scale(#{1/scale_x} #{1/scale_y}) translate(#{-translate_x} #{-translate_y})"}
                  class="transition-transform"
                >
                  <path
                    d="M 1 0 l 0 1 M 0 1 L 1 1"
                    class="stroke-base-300 moz-reset-width chrome-fix-width"
                    vector-effect="non-scaling-stroke"
                    style={"--chrome-stroke-width: #{scale_y}px"}
                  />
                </pattern>
              </defs>

              <rect width="1" height="1" fill="url(#grid)" class="transition-all" />
              <path
                d={
                  [
                    "M #{(@start_against * window(:maybeship) - @start_for) / (@end_for - @start_for)},0",
                    "L 1,#{(@end_for / window(:maybeship) - @start_against) / (@end_against - @start_against)}",
                    "L 1,#{(@end_for / window(:premiership) - @start_against) / (@end_against - @start_against)}",
                    "L #{(@start_against * window(:premiership) - @start_for) / (@end_for - @start_for)},0"
                  ]
                  |> Enum.join("\n")
                }
                class="fill-warning/15 transition-all"
              />
              <path
                d={
                  [
                    "M #{(@start_against * window(:premiership) - @start_for) / (@end_for - @start_for)},0",
                    "L 1,#{(@end_for / window(:premiership) - @start_against) / (@end_against - @start_against)}",
                    "L 1 0"
                  ]
                  |> Enum.join("\n")
                }
                class="fill-success/20 transition-all"
              />
              <path
                d={
                  [
                    "M #{(@start_against * window(:premiership) - @start_for) / (@end_for - @start_for)},0",
                    "L 1,#{(@end_for / window(:premiership) - @start_against) / (@end_against - @start_against)}"
                  ]
                  |> Enum.join("\n")
                }
                class="fill-transparent transition-all stroke-success stroke-2"
                vector-effect="non-scaling-stroke"
              />
              <path
                d={
                  [
                    "M #{(@start_against * window(:maybeship) - @start_for) / (@end_for - @start_for)},0",
                    "L 1,#{(@end_for / window(:maybeship) - @start_against) / (@end_against - @start_against)}"
                  ]
                  |> Enum.join("\n")
                }
                class="fill-transparent transition-all stroke-warning stroke-2"
                vector-effect="non-scaling-stroke"
              />
              <path
                d={
                  [
                    "M #{(@start_against * window(:finals) - @start_for) / (@end_for - @start_for)},0",
                    "L 1,#{(@end_for / window(:finals) - @start_against) / (@end_against - @start_against)}"
                  ]
                  |> Enum.join("\n")
                }
                class="fill-transparent transition-all stroke-info stroke-2"
                vector-effect="non-scaling-stroke"
                stroke-dasharray="20"
              />

              <path
                d={
                  [
                    "M 0,#{(@start_for / window(:spoon) - @start_against) / (@end_against - @start_against)}",
                    "L #{(@end_against * window(:spoon) - @start_for) / (@end_for - @start_for)},1",
                    "L 0,1",
                    "z"
                  ]
                  |> Enum.join("\n")
                }
                class="fill-error/20 transition-all"
              />
              <path
                d={
                  [
                    "M 0,#{(@start_for / window(:spoon) - @start_against) / (@end_against - @start_against)}",
                    "L #{(@end_against * window(:spoon) - @start_for) / (@end_for - @start_for)},1"
                  ]
                  |> Enum.join("\n")
                }
                class="fill-transparent transition-all stroke-error stroke-2"
                vector-effect="non-scaling-stroke"
              />
              <path
                d={
                  [
                    "M #{(@avg_points_for - @start_for) / (@end_for - @start_for)} 0",
                    "l 0 1",
                    "M 0 #{(@avg_points_against - @start_against) / (@end_against - @start_against)}",
                    "l 1 0"
                  ]
                  |> Enum.join(" ")
                }
                class="stroke-base-content/20 stroke-2 transition-all"
                vector-effect="non-scaling-stroke"
                stroke-dasharray="12"
              />
            </svg>
            <div class="contents isolate" id="teams" phx-update="stream">
              <.team_badge
                :for={
                  {dom_id, {team, {s_for, s_against}}} <-
                    @streams.teams
                }
                abbrev={team.abbrev}
                id={dom_id}
                percentage={s_for / s_against}
                style={
                  [
                    "left: #{(s_for - @start_for) / (@end_for - @start_for) * 100}%",
                    "top: #{(s_against - @start_against) / (@end_against - @start_against) * 100}%",
                    "z-index: #{(s_for / s_against * 1000) |> round}"
                  ]
                  |> Enum.reject(&is_nil/1)
                  |> Enum.join(";")
                }
                class=" -translate-x-1/2 -translate-y-1/2 absolute"
                title={"#{team.name}: #{s_for |> :erlang.float_to_binary(decimals: 1)} for, #{s_against  |> :erlang.float_to_binary(decimals: 1)} against"}
              />
            </div>
          </div>
        </div>
      </div>

      <div class="w-full max-w-screen-lg mx-auto px-4 flex flex-col gap-4">
        <section class="prose card bg-base-200 p-4 mx-auto max-w-none ">
          <h2 class="inline">What am I looking at?</h2>
          <p>
            This chart fundamentally just shows the AFL ladder's "percentage" column in a 2D format.
          </p>
          <p>
            Though I disagree with Fox Footy calling this the "premiership window",
            it does give an interesting insight into how a team is achieving their percentage over the season.
          </p>
          <p>
            Credit for this design goes to
            <a href="https://www.reddit.com/user/trapt777">u/trapt777</a>
            on Reddit,
            who has posted these for each round of the 2025 season.
          </p>
        </section>
        <section class="prose card bg-base-200 p-4 mx-auto max-w-none w-full">
          <h2>Key</h2>
          <table class="">
            <tbody>
              <tr>
                <td>
                  <div class="w-4 h-1 rounded bg-success" />
                </td>
                <td>The "premiership window" (Average percentage for flag winners in the AFL era)</td>
                <td>(percentage &ge; {window(:premiership) * 100}%)</td>
              </tr>
              <tr>
                <td>
                  <div class="w-4 h-1 rounded bg-warning" />
                </td>
                <td>
                  The "maybeship window" (Lowest percentage for a flag winner in the AFL era - Richmond 2019)
                </td>
                <td>(percentage &ge; {window(:maybeship) * 100}%)</td>
              </tr>
              <tr>
                <td>
                  <div class="w-4 h-1 rounded bg-info" />
                </td>
                <td>Average finals margin</td>
                <td>(percentage &ge; {window(:finals) * 100}%)</td>
              </tr>
              <tr>
                <td>
                  <div class="w-4 h-1 rounded bg-error" />
                </td>
                <td>Spoon territory</td>
                <td>(percentage &le; {window(:spoon) * 100}%)</td>
              </tr>
            </tbody>
          </table>
        </section>
      </div>

      <div class="tabs tabs-box items-center justify-center max-w-max mx-auto my-4 pr-2 sticky bottom-4">
        <details class="dropdown dropdown-top">
          <summary class="btn m-1">{@year}<.icon name="hero-chevron-up" /></summary>

          <div class="tabs tabs-box items-center justify-center max-w-max mx-auto my-4 dropdown-content">
            <.link
              :for={year <- @years}
              class={["tab w-full transition-all", @year == year && "tab-active"]}
              patch={~p"/premiership_window?year=#{year}"}
            >
              {year}
            </.link>
          </div>
        </details>
        <.link
          :for={round <- @rounds}
          :if={round}
          class={["tab transition-all", @round == round.id && "tab-active"]}
          patch={~p"/premiership_window?round=#{round}&year=#{@year}"}
        >
          {round}
        </.link>
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

  def average_score_for([], _team_id, _running_count, total_games) when total_games <= 0 do
    0
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

  def average_score_against([], _team_id, _running_count, total_games) when total_games <= 0 do
    0
  end

  def average_score_against([], _team_id, running_count, total_games) do
    running_count / total_games
  end

  def mount(_params, _, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(FootyLive.PubSub, @topic)
    end

    teams = FootyLive.Teams.list_teams()

    {:ok,
     socket
     |> assign(:route, :premiership_window)
     |> assign(:page_title, "Percentage Chart")
     |> assign(:years, FootyLive.Games.list_years())
     |> assign(:teams, teams)}
  end

  def handle_params(params, _uri, socket) do
    current_year = DateTime.utc_now().year

    year =
      case params do
        %{"year" => year} ->
          {year, _} = Integer.parse(year)
          year

        _ ->
          current_year
      end

    rounds = FootyLive.Games.list_rounds(year: year, hide_future: true)

    current_round = FootyLive.Games.current_round().id

    round =
      case params do
        %{"round" => round} ->
          {round, _} = Integer.parse(round)

          round

        _ when year == current_year ->
          current_round

        _ ->
          rounds
          |> Enum.at(-1)
          |> case do
            %{id: id} -> id
            _ -> nil
          end
      end

    games = FootyLive.Games.list_games(year: year)

    {:noreply,
     socket
     |> assign(round: round, year: year, rounds: rounds)
     |> calculate_and_assign_stats(socket.assigns.teams, games, round)}
  end

  def handle_info({:game_updated, game}, socket) do
    year = socket.assigns.year

    case game do
      %Game{year: ^year} ->
        teams = socket.assigns.teams
        games = FootyLive.Games.list_games(year: socket.assigns.year)

        {:noreply,
         calculate_and_assign_stats(socket, teams, games, socket.assigns.round, [
           game.hteamid,
           game.ateamid
         ])}

      _ ->
        {:noreply, socket}
    end
  end

  defp calculate_averages(averages) do
    Tracer.with_span "calculate_averages" do
      {total_for, total_against, count} =
        averages
        |> Map.values()
        |> Enum.reduce({0, 0, 0}, fn {for_score, against_score},
                                     {total_for, total_against, count} ->
          {total_for + for_score, total_against + against_score, count + 1}
        end)

      avg_points_for = if count > 0, do: total_for / count, else: 0
      avg_points_against = if count > 0, do: total_against / count, else: 0

      {avg_points_for, avg_points_against}
    end
  end

  defp calculate_and_assign_stats(socket, teams, games, max_round, team_ids \\ nil) do
    Tracer.with_span "calculate_and_assign_stats" do
      games =
        case max_round do
          _ when is_integer(max_round) ->
            games |> Enum.filter(&(&1.round <= max_round))

          _ ->
            games
        end

      averages =
        for %Team{id: id} <- teams do
          {id, {games |> average_score_for(id), games |> average_score_against(id)}}
        end
        |> Enum.filter(fn {_, {for, against}} -> for > 0 || against > 0 end)
        |> Enum.into(%{})

      max_for =
        averages |> Enum.reduce(0, fn {_id, {for, _against}}, current -> max(for, current) end)

      max_against =
        averages
        |> Enum.reduce(0, fn {_id, {_for, against}}, current -> max(against, current) end)

      min_for =
        averages
        |> Enum.reduce(250, fn {_id, {for, _against}}, current -> min(for, current) end)

      min_against =
        averages
        |> Enum.reduce(250, fn {_id, {_for, against}}, current -> min(against, current) end)

      teams =
        case team_ids do
          [_ | _] -> teams |> Enum.filter(&Enum.member?(team_ids, &1.id))
          _ -> teams
        end

      {avg_points_for, avg_points_against} = calculate_averages(averages)

      socket =
        socket
        |> assign(
          start_for: floor(min_for / 5) * 5 - 5,
          end_for: ceil(max_for / 5) * 5 + 5,
          start_against: floor(min_against / 5) * 5 - 5,
          end_against: ceil(max_against / 5) * 5 + 5,
          avg_points_for: avg_points_for,
          avg_points_against: avg_points_against
        )
        |> stream(
          :teams,
          for team <- teams do
            {team, averages[team.id]}
          end,
          dom_id: fn {team, _averages} -> "team-#{team.id}" end
        )

      teams
      |> Enum.filter(&is_nil(averages[&1.id]))
      |> Enum.reduce(
        socket,
        fn team, acc ->
          acc |> stream_delete_by_dom_id(:teams, "team-#{team.id}")
        end
      )
    end
  end
end

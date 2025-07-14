defmodule FootyLiveWeb.LadderLive do
  alias Squiggle.Game
  alias FootyLive.Games
  alias FootyLive.Teams
  use FootyLiveWeb, :live_view

  @default_team %{
    points: 0,
    played: 0,
    points_for: 0,
    points_against: 0
  }

  defp calculate_team_points(games, acc \\ %{})

  defp calculate_team_points([], acc) do
    acc
  end

  defp calculate_team_points([game | games], acc) do
    hteam =
      Map.get(acc, game.hteamid, @default_team)

    ateam =
      Map.get(acc, game.ateamid, @default_team)

    hteam = %{
      hteam
      | played: hteam.played + 1,
        points_for: hteam.points_for + game.hscore,
        points_against: hteam.points_against + game.ascore
    }

    ateam = %{
      ateam
      | played: ateam.played + 1,
        points_for: ateam.points_for + game.ascore,
        points_against: ateam.points_against + game.hscore
    }

    {hteam, ateam} =
      cond do
        game.hscore > game.ascore ->
          {%{hteam | points: hteam.points + 4}, ateam}

        game.hscore < game.ascore ->
          {hteam, %{ateam | points: ateam.points + 4}}

        game.hscore == game.ascore ->
          {%{hteam | points: hteam.points + 2}, %{ateam | points: ateam.points + 2}}

        true ->
          {hteam, ateam}
      end

    acc = acc |> Map.put(game.hteamid, hteam) |> Map.put(game.ateamid, ateam)

    calculate_team_points(games, acc)
  end

  defp get_games(year) do
    Games.list_games(year: year)
    |> Enum.reject(
      &(is_nil(&1.hteamid) || is_nil(&1.ateamid) || &1.complete == 0 || &1.is_final != 0)
    )
  end

  defp generate_ladder(team_points) do
    ladder =
      for {id, data} <- team_points do
        {data.points, data.points_for / data.points_against, data.played, id}
      end
      |> Enum.sort(&(&1 > &2))
      |> Enum.with_index()
      |> Enum.map(fn {{points, percentage, played, id}, rank} ->
        {rank + 1, points, percentage, played, id}
      end)

    max_played =
      Enum.reduce(team_points, 0, fn {_id, %{played: played}}, acc -> max(played, acc) end)

    {ladder, max_played}
  end

  def mount(params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(FootyLive.PubSub, "live_games")
    end

    teams = Teams.list_teams() |> Enum.map(&{&1.id, &1}) |> Enum.into(%{})

    year =
      case params do
        %{"year" => year} -> Integer.parse(year) |> elem(0)
        _ -> DateTime.utc_now().year
      end

    games = get_games(year)
    team_points = calculate_team_points(games)

    {ladder, max_played} = generate_ladder(team_points)

    {:ok,
     socket
     |> assign(
       teams: teams,
       ladder: ladder,
       max_played: max_played,
       year: year,
       years: FootyLive.Games.list_years()
     )}
  end

  def handle_info({:game_updated, game}, socket) do
    year = socket.assigns.year

    case game do
      %Game{year: ^year} ->
        games = get_games(year)

        team_points = calculate_team_points(games)

        {ladder, max_played} = generate_ladder(team_points)

        {:noreply, socket |> assign(ladder: ladder, max_played: max_played)}

      _ ->
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} route={:ladder}>
      <details class="dropdown dropdown-bottom mx-auto">
        <summary class="btn m-1">{@year}<.icon name="hero-chevron-down" /></summary>

        <div class="tabs tabs-box items-center justify-center max-w-max mx-auto  dropdown-content bg-base-300">
          <.link
            :for={year <- @years}
            class={["tab w-full transition-all", @year == year && "tab-active"]}
            navigate={~p"/?year=#{year}"}
          >
            {year}
          </.link>
        </div>
      </details>
      <div class="max-w-screen-lg md:card w-full bg-base-200 mx-auto">
        <.table id="ladder" rows={@ladder}>
          <:col :let={{rank, _points, _ratio, _played, _id}} label="#">{rank}</:col>
          <:col :let={{_rank, _points, ratio, _played, id}} label="Team">
            <div class="flex gap-2 items-center ">
              <div
                class={[
                  "size-9 transition-all rounded-full border-2 shadow border-base-200 text-white",
                  "flex items-center justify-center ",
                  cond do
                    ratio >= 1.3122 -> "ring ring-success"
                    ratio >= 1.137 -> "ring ring-warning"
                    ratio >= 1.02 -> "ring ring-neutral"
                    ratio <= 0.69 -> "ring ring-error"
                    true -> nil
                  end
                ]}
                data-club={@teams[id].abbrev}
              >
                <div class="initials text-xs font-semibold">{@teams[id].abbrev}</div>
              </div>
              {@teams[id].name}
            </div>
          </:col>
          <:col :let={{_rank, points, _ratio, played, _id}} label="Points">
            {points}<span
              :if={played < @max_played}
              class="text-primary"
              title={
                case @max_played - played do
                  1 -> "1 game behind"
                  v -> "#{v} games behind"
                end
              }
            >*</span>
          </:col>
          <:col :let={{_rank, _points, ratio, _played, _id}} label="Percentage">
            {(ratio * 100) |> Float.round(1)}%
          </:col>
        </.table>
      </div>
    </Layouts.app>
    """
  end
end

defmodule FootyLiveWeb.GamesLive do
  alias Squiggle.Game
  alias Squiggle.Team
  use FootyLiveWeb, :live_view
  alias FootyLive.{Games, Teams}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(FootyLive.PubSub, "live_games")
    end

    socket =
      socket
      |> assign(:page_title, "AFL Games")
      |> assign(:teams, Teams.list_teams())
      |> assign(:rounds, Games.list_rounds())
      |> assign(:round, 0)
      |> assign(:route, :games)
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    round_id =
      params
      |> Map.get("round", Games.current_round())
      |> case do
        round_id when is_integer(round_id) ->
          round_id

        %Games.Round{id: round_id} ->
          round_id

        round_id when is_binary(round_id) ->
          {round_id, _} = Integer.parse(round_id)
          round_id

        _ ->
          0
      end

    {:noreply,
     socket
     |> assign(:round, round_id)
     |> stream(:games, sort_games(Games.list_games_by_round(round_id)), reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} route={:games}>
      <div class="px-4 sm:px-6 lg:px-8">
        <.header class="flex items-center justify-between">
          AFL Games
          <:actions>
            <.button phx-click="refresh" phx-disable-with="Loading...">
              Refresh Games
            </.button>
          </:actions>
        </.header>
        <div class="tabs tabs-box">
          <.link
            :for={round <- @rounds}
            :if={round}
            class={["tab", @round == round.id && "tab-active"]}
            patch={~p"/games?round=#{round}"}
          >
            {round}
          </.link>
        </div>
        <div class="mt-8 flow-root">
          <.table id="games" rows={@streams.games}>
            <:col :let={{_id, game}} label="Date">{game.date |> format_date}</:col>
            <:col :let={{_id, game}} label="Home Team">
              <%= case Teams.get(game.hteamid) do %>
                <% %Team{name: name, abbrev: abbrev}-> %>
                  <div class="flex h-6 gap-2 items-center">
                    <.team_badge abbrev={abbrev} />
                    {name}
                  </div>
                <% _ -> %>
                  {game.hteam}
              <% end %>
            </:col>
            <:col :let={{_id, %Game{hgoals: hgoals, hbehinds: hbehinds}}} label="Home score">
              <div :if={!is_nil(hgoals)}>{format_score(hgoals, hbehinds)}</div>
            </:col>
            <:col :let={{_id, game}} label="Away Team">
              <%= case Teams.get(game.ateamid) do %>
                <% %Team{name: name, abbrev: abbrev}-> %>
                  <div class="flex gap-2 items-center">
                    <.team_badge abbrev={abbrev} />
                    {name}
                  </div>
                <% _ -> %>
                  {game.ateam}
              <% end %>
            </:col>
            <:col :let={{_id, %Game{agoals: agoals, abehinds: abehinds}}} label="Away score">
              <div :if={!is_nil(agoals)}>{format_score(agoals, abehinds)}</div>
            </:col>
            <:col :let={{_id, game}} label="Status">
              {game_status(game)}
            </:col>
          </.table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp sort_games(games) do
    Enum.sort_by(games, &{&1.round, &1.date})
  end

  @impl true
  def handle_info({:game_updated, %{round: round} = game}, socket) do
    case socket.assigns do
      %{round: ^round} ->
        {:noreply, stream(socket, :games, [game])}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    socket = assign(socket, :loading, true)
    Games.refresh()
    {:noreply, socket |> push_patch(to: ~p"/games?round=#{socket.assigns.round}", replace: true)}
  end

  defp format_date(date) do
    date
    |> DateTime.from_iso8601()
    |> case do
      {:ok, datetime, _} ->
        Calendar.strftime(datetime, "%d %b %Y %H:%M")

      _ ->
        date
    end
  end

  defp format_score(goals, behinds) do
    "#{goals}.#{behinds} (#{goals * 6 + behinds})"
  end

  defp game_status(%{complete: 100}), do: "Final"
  defp game_status(%{complete: 0}), do: "Scheduled"
  defp game_status(%{timestr: timestr}) when not is_nil(timestr), do: timestr
  defp game_status(%{complete: n}) when n > 0, do: "In Progress"
  defp game_status(_), do: "Unknown"
end

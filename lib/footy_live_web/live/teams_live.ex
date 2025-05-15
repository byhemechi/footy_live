defmodule FootyLiveWeb.TeamsLive do
  use FootyLiveWeb, :live_view
  alias FootyLive.Teams

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to team updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(FootyLive.PubSub, "teams")
    end

    socket =
      socket
      |> assign(:page_title, "AFL Teams")
      |> assign(:teams, Teams.list_teams())

    {:ok, socket}
  end

  @impl true
  def render(%{teams: teams} = assigns) do
    ~H"""
    <Layouts.app {assigns}>
      <div class="px-4 sm:px-6 lg:px-8">
        <div class="sm:flex sm:items-center">
          <div class="sm:flex-auto">
            <h1 class="text-base font-semibold leading-6 text-gray-900">AFL Teams</h1>
            <p class="mt-2 text-sm text-gray-700">
              A list of all AFL teams and their details.
            </p>
          </div>
          <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
            <.button phx-click="refresh" phx-disable-with="Loading...">
              Refresh Teams
            </.button>
          </div>
        </div>
        <div class="mt-8 flow-root">
          <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
            <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
              <.table id="teams" rows={teams}>
                <:col :let={team} label="ID">{team.id}</:col>
                <:col :let={team} label="Name">{team.name}</:col>
                <:col :let={team} label="Abbreviation">{team.abbrev}</:col>
                <:col :let={team} label="Logo">
                  <%= if team.logo do %>
                    <img src={"https://squiggle.au/" <> team.logo} alt={team.name} class="h-8 w-8" />
                  <% end %>
                </:col>
                <:col :let={team} label="Debut">{team.debut}</:col>
                <:col :let={team} label="Status">{team_status(team)}</:col>
              </.table>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    teams = Teams.refresh()
    {:noreply, assign(socket, :teams, teams)}
  end

  @impl true
  def handle_info({:teams_updated, teams}, socket) do
    {:noreply, assign(socket, :teams, teams)}
  end

  defp team_status(%{retired: year}) when is_integer(year), do: "Retired #{year}"
  defp team_status(_team), do: "Active"
end

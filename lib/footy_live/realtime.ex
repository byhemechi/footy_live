defmodule FootyLive.Realtime do
  use GenServer
  require Logger

  @timeout :timer.minutes(1)
  @initial_retry_delay :timer.seconds(1)
  @max_retry_delay :timer.minutes(5)

  def init(_init_arg) do
    state = %{
      pid: self(),
      retry_count: 0,
      retry_delay: @initial_retry_delay,
      reset_timer: nil,
      realtime_task: nil
    }

    state = start_stream(state)
    {:ok, state}
  end

  defp start_stream(state) do
    resp =
      Req.get("https://sse.squiggle.com.au/events",
        into: :self,
        headers: %{
          "user-agent" => "Elixir FootyLive - @byhemechi on twitter/discord, hello@george.id.au"
        }
      )

    %{state | realtime_task: resp}
  end

  def handle_info(:check_connection, state) do
    Logger.warning("No messages received in the last minute, reconnecting stream")
    new_delay = min(state.retry_delay * 2, @max_retry_delay)

    Process.sleep(state.retry_delay)

    new_state = %{state | retry_count: state.retry_count + 1, retry_delay: new_delay}

    {:noreply, start_stream(new_state)}
  end

  def handle_info({:squiggle_event, event}, state) do
    event
    |> handle_squiggle_event()

    # Reset retry count and delay on successful event
    new_state = %{state | retry_count: 0, retry_delay: @initial_retry_delay}

    {:noreply, new_state}
  end

  def handle_info({_pool, {:data, data}}, state) do
    if !is_nil(state.reset_timer), do: Process.cancel_timer(state.reset_timer)

    new_timer = Process.send_after(self(), :check_connection, @timeout)

    {events, _rest} = ServerSentEvents.parse(data)

    for event <- events do
      send(self(), {:squiggle_event, event})
    end

    {:noreply, %{state | reset_timer: new_timer}}
  end

  defp handle_squiggle_event(%{event: "timestr", data: event_data}) do
    event = Jason.decode!(event_data)

    if game = FootyLive.Games.get_game(event["gameid"]) do
      game
      |> Map.put(:timestr, event["timestr"])
      |> FootyLive.Games.put_game()
    end
  end

  defp handle_squiggle_event(%{event: "score", data: event_data}) do
    event = Jason.decode!(event_data)

    case FootyLive.Games.get_game(event["gameid"]) do
      %Squiggle.Game{} = game ->
        event["score"]
        |> Enum.reduce(game, fn {k, v}, acc ->
          acc |> Map.put(String.to_existing_atom(k), v)
        end)
        |> Map.put(:timestr, event["timestr"])
        |> Map.put(:complete, event["complete"])
        |> FootyLive.Games.put_game()

      nil ->
        FootyLive.Games.refresh()
    end
  end

  defp handle_squiggle_event(%{event: "game", data: event_data}) do
    event_data
    |> Jason.decode!()
    |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
    |> then(&struct(Squiggle.Game, &1))
    |> FootyLive.Games.put_game()
  end

  defp handle_squiggle_event(_event), do: :ok

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, nil, args)
  end
end

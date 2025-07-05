defmodule FootyLive.Realtime do
  use GenServer
  require Logger

  @timeout :timer.minutes(1)

  def init(_init_arg) do
    state = %{pid: self()}
    state = start_stream(state)
    {:ok, state}
  end

  defp start_stream(state) do
    Task.start_link(fn ->
      Req.get("https://api.squiggle.com.au/sse/events",
        into: fn {:data, data}, {req, res} ->
          # Reset the connection timer since we received data
          pid = Req.Request.get_private(req, :pid) || state.pid
          old_timer = Req.Request.get_private(req, :timer)
          if old_timer, do: Process.cancel_timer(old_timer)

          new_timer = Process.send_after(pid, :check_connection, @timeout)

          # Process SSE data
          buffer = Req.Request.get_private(req, :sse_buffer, "")
          {events, new_buffer} = ServerSentEvents.parse(buffer <> data)

          req =
            req
            |> Req.Request.put_private(:timer, new_timer)
            |> Req.Request.put_private(:pid, pid)
            |> Req.Request.put_private(:sse_buffer, new_buffer)

          if events != [] do
            for event <- events do
              send(pid, {:squiggle_event, event})
            end
          end

          {:cont, {req, res}}
        end,
        headers: %{
          "user-agent" => "Elixir FootyLive -@byhemechi on twitter"
        }
      )
    end)

    state
  end

  def handle_info(:check_connection, state) do
    Logger.warning("No messages received in the last minute, reconnecting stream")
    {:noreply, start_stream(state)}
  end

  def handle_info({:squiggle_event, event}, state) do
    event
    |> handle_squiggle_event()

    {:noreply, state}
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

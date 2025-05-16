defmodule FootyLive.Realtime do
  use GenServer

  def init(_init_arg) do
    pid = self()

    Task.start_link(fn ->
      Req.get("https://api.squiggle.com.au/sse/events",
        into: fn {:data, data}, {req, res} ->
          buffer = Req.Request.get_private(req, :sse_buffer, "")
          {events, buffer} = ServerSentEvents.parse(buffer <> data)
          Req.Request.put_private(req, :sse_buffer, buffer)

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

    {:ok, nil}
  end

  def handle_info({:squiggle_event, %{event: "score", data: event}}, state) do
    event = Jason.decode!(event)

    game = FootyLive.Games.get_game(event["gameid"])

    case game do
      %Squiggle.Game{} ->
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

    {:noreply, state}
  end

  def handle_info({:squiggle_event, %{event: "game", data: event}}, state) do
    event =
      Jason.decode!(event)
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)

    struct(Squiggle.Game, event)
    |> FootyLive.Games.put_game()

    {:noreply, state}
  end

  def handle_info({:squiggle_event, %{event: "message", data: message_data}}, state) do
    IO.inspect(Jason.decode!(message_data), label: "Message from Squiggle")
    {:noreply, state}
  end

  def handle_info({:squiggle_event, _event}, state) do
    {:noreply, state}
  end

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, nil, args)
  end
end

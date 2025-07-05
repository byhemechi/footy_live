defmodule FootyLive.Games.Round do
  defstruct [:id, kind: :home_and_away]

  def to_iodata(%FootyLive.Games.Round{id: id, kind: :final}) do
    ["F", Integer.to_string(id)]
  end

  def to_iodata(%FootyLive.Games.Round{kind: :grand_final}) do
    ["GF"]
  end

  def to_iodata(%FootyLive.Games.Round{id: id}) do
    [Integer.to_string(id)]
  end

  def from_game(%Squiggle.Game{round: round, is_final: is_final}) do
    %__MODULE__{
      kind:
        case is_final do
          0 -> :home_and_away
          final when final in 1..5 -> :final
          6 -> :grand_final
        end,
      id: round
    }
  end
end

defimpl String.Chars, for: FootyLive.Games.Round do
  def to_string(round) do
    FootyLive.Games.Round.to_iodata(round) |> IO.iodata_to_binary()
  end
end

defimpl Phoenix.HTML.Safe, for: FootyLive.Games.Round do
  def to_iodata(data), do: FootyLive.Games.Round.to_iodata(data)
end

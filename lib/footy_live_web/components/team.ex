defmodule FootyLiveWeb.Team do
  use Phoenix.Component
  use FootyLiveWeb, :verified_routes

  def window(:premiership), do: 1.3122
  def window(:maybeship), do: 1.137
  def window(:finals), do: 1.02
  def window(:spoon), do: 0.69

  attr :abbrev, :string, required: true
  attr :percentage, :float, default: 1.0
  attr :rest, :global, include: ~w(style)

  def team_badge(assigns) do
    ~H"""
    <div
      class={[
        "size-9 transition-all rounded-full border-2 shadow border-base-200 text-white",
        "flex items-center justify-center club-badge",
        cond do
          @percentage >= window(:premiership) -> "ring ring-success"
          @percentage >= window(:maybeship) -> "ring ring-warning"
          @percentage >= window(:finals) -> "ring ring-neutral"
          @percentage <= window(:spoon) -> "ring ring-error"
          true -> nil
        end,
        @rest[:class]
      ]}
      data-club={@abbrev}
      style={
        [
          case @abbrev do
            "SYD" -> "--club-image: url(#{~p"/images/opera-house.svg"})"
            "MEL" -> "--club-image: url(#{~p"/images/melbourne-shape.svg"})"
            _ -> nil
          end,
          @rest[:style]
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(";")
      }
      {@rest}
    >
      <div class="initials text-xs font-semibold">{@abbrev}</div>
    </div>
    """
  end
end

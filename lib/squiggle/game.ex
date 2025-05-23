defmodule Squiggle.Game do
  @moduledoc """
  A struct representing an AFL game from the Squiggle API.
  """

  use Memento.Table,
    attributes: [
      :id,
      :year,
      :round,
      :date,
      :venue,
      :ateam,
      :hteam,
      :ateamid,
      :hteamid,
      :agoals,
      :hgoals,
      :abehinds,
      :hbehinds,
      :ascore,
      :hscore,
      :complete,
      :timestr,
      :is_grand_final,
      :is_final
    ],
    index: [:year, :round]
end

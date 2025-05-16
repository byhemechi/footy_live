defmodule Squiggle.Team do
  @derive Jason.Encoder
  defstruct [
    :id,
    :name,
    :logo,
    :abbrev,
    :debut,
    :retirement
  ]
end

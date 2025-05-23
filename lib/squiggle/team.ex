defmodule Squiggle.Team do
  @derive Jason.Encoder
  use Memento.Table,
    attributes: [
      :id,
      :name,
      :logo,
      :abbrev,
      :debut,
      :retirement
    ],
    type: :ordered_set
end

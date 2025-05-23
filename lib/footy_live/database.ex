defmodule FootyLive.Database do
  @doc """
  Sets up the Game and Team tables' disk copies. Only needs to be run once per node.
  """
  def initialise_disk_copies do
    nodes = [node()]

    # Create the schema
    Memento.stop()
    Memento.Schema.create(nodes)
    Memento.start()

    # Create your tables with disc_copies (only the ones you want persisted on disk)
    Memento.Table.create!(Squiggle.Team, disc_copies: nodes)
    Memento.Table.create!(Squiggle.Game, disc_copies: nodes)
  end
end

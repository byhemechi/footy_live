defmodule FootyLive.Database do
  require Logger

  @doc """
  Sets up the Game and Team tables' disk copies. Only needs to be run once per node.
  """
  def init do
    nodes = [node()]

    Memento.stop()
    Memento.Schema.create(nodes)
    Memento.start()

    # Check if tables exist
    case Memento.Table.wait([Squiggle.Team, Squiggle.Game]) do
      {:timeout, to_create} ->
        for table <- to_create do
          Logger.info("Creating table #{table}")
          Memento.Table.create!(table, disc_copies: nodes)
        end

        :ok

      :ok ->
        Logger.info("Tables already exist")
        # All tables already exist, do nothing
        :ok
    end
  end
end

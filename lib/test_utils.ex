defmodule TestUtils do
  @moduledoc """
  Handy functions for test code
  """

  defmacro __using__(_) do
    quote location: :keep do
      def setup_corpus() do
        Indexstore.start_link()
        Documentstore.start_link()
        Indexer.test_corpus()
          |> Enum.each(&Store.store(&1, "test-index"))

        :ok
      end

      def ids(hits) do
        hits
          |> Enum.map(fn({id, _}) -> id end)
      end

      def locations(hits) do
        hits
          |> Enum.flat_map(fn{_, locs} -> Set.to_list(locs) end)
          |> Enum.map(fn(l) -> l.field end)
          |> Enum.uniq
      end
    end
  end
end

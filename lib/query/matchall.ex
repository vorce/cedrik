defmodule Query.MatchAll do
  @moduledoc """
  Match all query
  """

  require Logger

  defstruct []
  @type t :: %Query.MatchAll{}

  defimpl Search, for: Query.MatchAll do
    def search(_query, indices) do
      Logger.debug("Searching for all documents in #{inspect(indices)}")
      hits = all_in(indices)
      %Result{hits: Enum.to_list(hits)}
    end

    def all_in(indices) do
      indices
      |> IndexSupervisor.list()
      |> Enum.flat_map(fn {p, _n, m} -> m.document_ids(p) end)
      |> Enum.map(fn id -> {id, MapSet.new()} end)
    end
  end
end

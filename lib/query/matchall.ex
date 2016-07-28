defmodule Query.MatchAll do
  defstruct type: :all
  @type t :: %Query.MatchAll{type: Atom.t}

  defimpl Search, for: Query.MatchAll do
    def search(_query, indices) do
      IO.puts("Searching for all documents in #{inspect indices}")
      hits = all_in(indices)
      %Result{ hits: Enum.to_list(hits) }
    end

    def all_in(indices) do
      IndexSupervisor.index_pids(indices)
        |> Enum.flat_map(fn({p, m}) -> m.document_ids(p) end)
        |> Enum.map(fn(id) -> {id, HashSet.new} end)
    end
  end
end

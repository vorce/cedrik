defmodule Query.MatchAll do
  defstruct type: :all
  @type t :: %Query.MatchAll{type: Atom.t}

  defimpl Search, for: Query.MatchAll do
    def search(_query, indices) do
      IO.puts("Searching for all documents in #{indices}")
      hits = indices
        |> Stream.flat_map(&all_in(&1))
      %Result{ hits: Enum.to_list(hits) }
    end

    def all_in(index) do
      AgentIndex.get(index).document_ids
        |> Enum.map(fn(id) -> {id, HashSet.new} end) # Locations does not make sense here
    end
  end
end


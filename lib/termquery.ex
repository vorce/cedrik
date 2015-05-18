defmodule TermQuery do
  defstruct field: :id, value: nil, type: :term
  @type t :: %TermQuery{field: Atom.t, value: any, type: Atom.t}

  defimpl Search, for: TermQuery do
    def search(query, indices) do
      IO.puts("Searching for term #{query.value} in field #{query.field}, in indices #{indices}")
      hits = indices |> Enum.flat_map(&term_in(&1, query))
      %Result{ hits: hits }
    end

    def term_in(index, query) do
      Indexstore.get(index).terms
        |> Map.get(query.value, %{}) # Map with docIds as keys
        |> Map.keys # TODO we disregard positions/highlights for now
        |> Enum.map(&Documentstore.get(&1))
    end
  end
end


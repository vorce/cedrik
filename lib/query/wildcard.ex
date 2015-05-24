defmodule Query.Wildcard do
  defstruct fields: [], value: nil, type: :wildcard
  @type t :: %Query.Wildcard{fields: List.t, value: any, type: Atom.t}

  defimpl Search, for: Query.Wildcard do
    def search(query, indices) do
      ending_wildcard(query, indices)
    end

    def ending_wildcard(query, indices) do
      hits = indices
        |> Enum.flat_map(&leading_terms(&1, query))
      %Result{hits: hits} 
    end

    def leading_terms(index, query) do
      no_wc = String.replace(query.value, "*", "")
      terms = Indexstore.get(index).terms
      terms
        |> Map.keys
        |> Enum.filter(fn(k) ->
          String.starts_with?(k, no_wc) end)
        |> Enum.map(&Map.get(terms, &1, %{}))
        |> Enum.reduce(&Indexer.merge_term_locations(&1, &2))
        |> Query.Term.remove_irrelevant(query.fields)
    end
  end
end

defmodule Query.Wildcard do
  defstruct fields: [], value: nil, type: :wildcard
  @type t :: %Query.Wildcard{fields: List.t, value: any, type: Atom.t}

  defimpl Search, for: Query.Wildcard do
    def search(query, indices) do
      parts = String.split(query.value, "*")
      cond do
        length(parts) == 2 && parts |> Enum.reverse |> hd == "" ->
          ending_wildcard(query, indices)
        length(parts) == 2 && hd(parts) == "" ->
          leading_wildcard(query, indices)
      end
    end

    def leading_wildcard(query, indices) do
      hits = indices
        |> Enum.flat_map(&ending_terms(&1, query))
      %Result{hits: hits}
    end

    def ending_wildcard(query, indices) do
      hits = indices
        |> Enum.flat_map(&leading_terms(&1, query))
      %Result{hits: hits} 
    end

    def ending_terms(index, query) do
      filtered_terms(index, query, &String.ends_with?/2)
    end

    def leading_terms(index, query) do
      filtered_terms(index, query, &String.starts_with?/2)
    end

    def filtered_terms(index, query, filter_fn) do
      no_wc = String.replace(query.value, "*", "")
      terms = Indexstore.get(index).terms
      terms
        |> Map.keys
        |> Stream.filter(&filter_fn.(&1, no_wc))
        |> Stream.map(&Map.get(terms, &1, %{}))
        |> Enum.reduce(&Indexer.merge_term_locations(&1, &2))
        |> Query.Term.remove_irrelevant(query.fields)
    end
  end
end

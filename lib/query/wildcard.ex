defmodule Query.Wildcard do
  @moduledoc """
  Wildcard query
  """

  defstruct fields: [], value: nil
  @type t :: %Query.Wildcard{fields: List.t, value: any}

  defimpl Search, for: Query.Wildcard do
    def search(query, indices) do
      parts = String.split(query.value, "*")
      cond do
        length(parts) == 2 && parts |> Enum.reverse |> hd == "" ->
          ending_wildcard(query, indices)
        length(parts) == 2 && hd(parts) == "" ->
          leading_wildcard(query, indices)
        true -> raise("No wildcard character ('*') passed to wildcard query")
      end
    end

    def leading_wildcard(query, indices) do
      hits = Enum.flat_map(indices, &ending_terms(&1, query))
      %Result{hits: hits}
    end

    def ending_wildcard(query, indices) do
      hits = Enum.flat_map(indices, &leading_terms(&1, query))
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

      index
      |> AgentIndex.terms()
      |> Stream.filter(&filter_fn.(&1, no_wc))
      |> Stream.map(&AgentIndex.term_positions(&1, index))
      |> Enum.reduce(%{}, &Index.merge_term_locations(&1, &2))
      |> Query.Term.remove_irrelevant(query.fields)
    end
  end
end

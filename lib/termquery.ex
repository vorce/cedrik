defmodule TermQuery do
  defstruct fields: [], value: nil, type: :term
  @type t :: %TermQuery{fields: List.t, value: any, type: Atom.t}

  defimpl Search, for: TermQuery do
    def search(query, indices) do
      IO.puts("Searching for term '#{query.value}' in fields '#{fields(query.fields)}', in indices '#{indices}'")
      hits = indices |> Enum.flat_map(&term_in(&1, query))
      %Result{ hits: hits }
    end

    def term_in(index, query) do
      Indexstore.get(index).terms
        |> Map.get(query.value, %{}) # Map with docIds as keys
        |> Enum.filter(fn({_id, locs}) ->
          on_fields(locs, query.fields) != [] end) # Only hits in correct fields
        #|> Map.keys # TODO we disregard positions/highlights for now
        #|> Enum.map(&Documentstore.get(&1))
    end

    def on_fields(locs, []) do locs end
    def on_fields(locs, fields) do
      locs
        |> Enum.filter(fn(%Location{} = l) ->
          Enum.member?(fields, l.field) end)
    end

    def fields([]) do "*" end
    def fields(fs) do
      Enum.join(fs, ", ")
    end
  end
end


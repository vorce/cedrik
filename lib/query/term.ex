defmodule Query.Term do
  defstruct fields: [], value: nil, type: :term
  @type t :: %Query.Term{fields: List.t, value: any, type: Atom.t}

  defimpl Search, for: Query.Term do
    def search(query, indices) do
      IO.puts("Searching for term '#{query.value}' in fields '#{fields(query.fields)}', in indices '#{Enum.join(indices, ", ")}'")
      hits = indices |> Enum.flat_map(&term_in(&1, query))
      %Result{ hits: hits }
    end

    def term_in(index, query) do
      Indexstore.get(index).terms
        |> Map.get(query.value, %{}) # Map with docIds as keys
        |> Query.Term.remove_irrelevant(query.fields)
    end

    def fields([]) do "*" end
    def fields(fs) do
      Enum.join(fs, ", ")
    end
  end

  def remove_irrelevant(hits, fields) do
    hits
      |> Enum.map(fn({id, locs}) ->
        ls = Query.Term.on_fields(locs, fields)
        {id, Enum.into(ls, HashSet.new)}
      end)
      |> Enum.filter(fn({_id, locs}) ->
        not Enum.empty?(locs) end)
  end

  def on_fields(locs, []) do locs end
  def on_fields(locs, fields) do
    locs
      |> Enum.filter(fn(%Location{} = l) ->
        Enum.member?(fields, l.field) end)
  end

  def fix_locs({id, locs}, fields) do
    g = locs
      |> Enum.filter(fn(%Location{} = l) ->
        Enum.member?(fields, l.field)
      end)
    {id, g}
  end
end


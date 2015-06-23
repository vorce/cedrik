defmodule Query.Term do
  defstruct fields: [], value: nil, type: :term
  @type t :: %Query.Term{fields: List.t, value: any, type: Atom.t}

  defimpl Search, for: Query.Term do
    def search(query, indices) do
      IO.puts("Searching for term '#{query.value}' in fields '#{fields(query.fields)}', in indices '#{Enum.join(indices, ", ")}'")
      hits = indices
        |> Stream.flat_map(&term_in(&1, query))
        |> Enum.to_list
        |> Enum.sort(&Query.Term.hit_frequency/2)
      %Result{ hits: hits }
    end

    def term_in(index, query) do
      AgentIndex.terms(index)
      # AgentIndex.get(index).terms
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
      |> Stream.map(fn({id, locs}) ->
        ls = Query.Term.on_fields(locs, fields)
        {id, Enum.into(ls, HashSet.new)}
      end)
      |> Stream.filter(fn({_id, locs}) ->
        not Enum.empty?(locs) end)
  end

  def on_fields(locs, []) do locs end
  def on_fields(locs, fields) do
    locs
      |> Stream.filter(fn(%Location{} = l) ->
        Enum.member?(fields, l.field) end)
  end

  def hit_frequency({_i1, ls1}, {_i2, ls2}) do
    Set.size(ls1) > Set.size(ls2)
  end
end


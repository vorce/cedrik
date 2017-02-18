defmodule Query.Term do
  @moduledoc """
  Term query is the simplest query, matching a specific word.
  The term query also acts as a building block for a lot of other
  types of queries.
  """

  require Logger

  defstruct fields: [], value: nil
  @type t :: %Query.Term{fields: List.t, value: any}

  defimpl Search, for: Query.Term do
    def search(query, indices) do
      Logger.debug("Searching for term '#{query.value}' in fields '#{fields(query.fields)}', in indices '#{Enum.join(indices, ", ")}'")

      hits = indices
      |> IndexSupervisor.list()
      |> Stream.flat_map(&term_in(&1, query))
      |> Enum.to_list
      |> Enum.sort(&Query.Term.hit_frequency/2)
      %Result{hits: hits}
    end

    def term_in({pid, _name, module}, query) do
      query.value
      |> module.term_positions(pid)
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
      {id, Enum.into(ls, MapSet.new)}
    end)
    |> Stream.reject(fn({_id, locs}) ->
      Enum.empty?(locs)
    end)
  end

  def on_fields(locs, []) do locs end
  def on_fields(locs, fields) do
    Stream.filter(locs, fn(%Location{} = l) ->
      Enum.member?(fields, l.field)
    end)
  end

  def hit_frequency({_i1, ls1}, {_i2, ls2}) do
    MapSet.size(ls1) > MapSet.size(ls2)
  end
end

defmodule BooleanQuery do
  defstruct must: [], optional: [], must_not: [], type: :boolean
  @type t :: %BooleanQuery{
    must: List.t,
    optional: List.t,
    must_not: List.t,
    type: Atom.t,
  }

  defimpl Search, for: BooleanQuery do
    def search(%BooleanQuery{optional: [], must: [], must_not: []} = _q, indices) do
      Search.search(%MatchAll{}, indices)
    end

    def search(%BooleanQuery{optional: opt, must: [], must_not: []} = _q, indices) do
      opt
        |> Enum.map(&Search.search(&1, indices))
        |> Enum.reduce(fn(hs1, hs2) ->
          %Result{hits: Enum.concat(hs1.hits, hs2.hits) |> Enum.uniq} end)
    end

    def search(%BooleanQuery{must: must, optional: _, must_not: []} = _q, indices) do
      must
        |> Enum.map(&Search.search(&1, indices))
        |> Enum.reduce(fn(hs1, hs2) ->
          %Result{hits: intersecting(hs1.hits, hs2.hits)} end)
    end

    def search(query, indices) do
      nope = fn -> Search.search(%BooleanQuery{
          must: [],
          optional: query.must_not,
          must_not: []},
        indices) end

      res = fn -> Search.search(%BooleanQuery{
          must: query.must,
          optional: query.optional,
          must_not: []},
        indices) end

      both = Task.async(fn ->
        e = Task.async(nope)
        i = Task.async(res)
        {Task.await(e), Task.await(i)}
      end)
      {excl, incl} = Task.await(both)

      filtered = incl.hits
        |> Enum.filter(fn({i, _l}) ->
          not Enum.member?(ids(excl.hits), i) end)

      %Result{hits: filtered}
    end

    def ids(hits) do
      hits
        |> Enum.map(fn({id, _l}) -> id end)
    end

    def intersecting(hits1, hits2) do
      hs1 = Enum.into(hits1, %{})
      hs2 = Enum.into(hits2, %{})

      Set.intersection(hs1 |> Map.keys |> Enum.into(HashSet.new),
                       hs2 |> Map.keys |> Enum.into(HashSet.new))
        |> Enum.map(fn(i) ->
          {i, Set.union(Map.get(hs1, i, HashSet.new),
            Map.get(hs2, i, HashSet.new))} end)
    end
  end
end

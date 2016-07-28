defmodule Query.Boolean do
  defstruct must: [], optional: [], must_not: [], type: :boolean
  @type t :: %Query.Boolean{
    must: List.t,
    optional: List.t,
    must_not: List.t,
    type: Atom.t,
  }

  defimpl Search, for: Query.Boolean do
    def search(%Query.Boolean{optional: [], must: [], must_not: []} = _q, indices) do
      Search.search(%Query.MatchAll{}, indices)
    end

    def search(%Query.Boolean{optional: opt, must: [], must_not: []} = _q, indices) do
      opt
        |> Stream.map(&Search.search(&1, indices))
        |> Enum.reduce(fn(hs1, hs2) ->
          %Result{hits: Enum.concat(hs1.hits, hs2.hits) |> Enum.uniq} end)
    end

    def search(%Query.Boolean{must: must, optional: _, must_not: []} = _q, indices) do
      must
        |> Stream.map(&Search.search(&1, indices))
        |> Enum.reduce(fn(hs1, hs2) ->
          %Result{hits: intersecting(hs1.hits, hs2.hits)} end)
    end

    def search(query, indices) do
      nope = fn -> Search.search(%Query.Boolean{
          must: [],
          optional: query.must_not,
          must_not: []},
        indices) end

      res = fn -> Search.search(%Query.Boolean{
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
        |> Stream.reject(fn({i, _l}) ->
          Enum.member?(ids(excl.hits), i) end)

      %Result{hits: Enum.to_list(filtered)}
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
        |> Stream.map(fn(i) ->
          {i, Set.union(Map.get(hs1, i, HashSet.new),
            Map.get(hs2, i, HashSet.new))} end)
        |> Enum.to_list
    end
  end
end

defmodule CedrikTest do
  use ExUnit.Case

  test "indexing one doc" do
    Indexstore.start_link()
    Documentstore.start_link()

    index_name = "index1"
    doc = hd(Indexer.test_corpus)
    {:ok, index} = Indexer.index_doc(index_name, doc)
    
    assert index.name == index_name
    assert Set.size(index.document_ids) == 1
    assert Set.member?(index.document_ids, doc.id)
    assert Map.size(index.terms) > 0
  end

  #test "querying all" do
  #  assert Searcher.search(Index.index(name: "q-all", document_ids: Set.put(HashSet.new, 1)),
  #    Request.request(query: Query.all,
  #      views: %{"c" => View.count}))
  #  == 1
  #end
  test "search for all docs" do
    Indexstore.start_link()
    Documentstore.start_link()

    idx = %Index{name: "all-q",
      document_ids: Set.put(HashSet.new, 0),
      terms: %{"foo" => %{0 => [%Location{field: :body, position: 0}]}}}
    
    Indexer.test_corpus |> hd |> Documentstore.put
    Indexstore.put(idx)
    query = %AllQuery{}
    indices = [idx.name]
    result = Search.search(query, indices)
    assert length(result.hits) == 1
    assert result.hits |> Enum.map(fn(d) -> d.id end) |> Enum.member?(0)
  end
end

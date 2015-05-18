defmodule CedrikTest do
  use ExUnit.Case


  setup_all do
    Indexstore.start_link()
    Documentstore.start_link()
    Indexer.test_corpus()
      |> Enum.each(&Indexer.index_doc(&1, "test-index"))

    :ok
  end

  test "indexing one doc" do
    index_name = "index1"
    doc = hd(Indexer.test_corpus)
    {:ok, index} = Indexer.index_doc(doc, index_name)
    
    assert index.name == index_name
    assert Set.size(index.document_ids) == 1
    assert Set.member?(index.document_ids, doc.id)
    assert Map.size(index.terms) > 0
  end

  test "search for all docs" do
    idx = %Index{name: "all-q",
      document_ids: Set.put(HashSet.new, 0),
      terms: %{"foo" => %{0 => [%Location{field: :body, position: 0}]}}}
    
    Indexer.test_corpus |> hd |> Documentstore.put
    Indexstore.put(idx)
    result = Search.search(%MatchAll{}, [idx.name])
    assert length(result.hits) == 1
    assert result.hits |> ids |> Enum.member?(0)
  end

  test "search for specific term" do
    result = Search.search(%TermQuery{fields: [:title], value: "Pojke"}, ["test-index"])
    assert length(result.hits) == 1
    assert hd(result.hits).id == 3
  end

  test "search for term with multiple hits" do
    result = Search.search(%TermQuery{fields: [:body], value: "att"},
      ["foo", "test-index"])
    assert length(result.hits) > 1
    assert result.hits |> ids |> Enum.sort ==
      [0, 1, 2]
  end

  test "term query obeys field parameter" do
    result = Search.search(%TermQuery{fields: [:body], value: "cedrik"},
      ["test-index"])
    assert result.hits |> ids == [42]
  end

  test "term query on many fields" do
    r = Search.search(%TermQuery{fields: [:title, :body], value: "cedrik"},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [42, 666]
  end

  test "term query without fields looks at all" do
    r = Search.search(%TermQuery{fields: [], value: "cedrik"},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [42, 666]
  end

  def ids(hits) do
    hits |> Enum.map(fn(d) -> d.id end)
  end
end

defmodule CedrikTest do
  use ExUnit.Case


  setup_all do
    Indexstore.start_link()
    Documentstore.start_link()
    Indexer.test_corpus()
      |> Enum.each(&Store.store(&1, "test-index"))

    :ok
  end

  test "indexing one doc" do
    index_name = "index1"
    doc = hd(Indexer.test_corpus)
    {:ok, index} = Store.store(doc, index_name)
    
    assert index.name == index_name
    assert Set.size(index.document_ids) == 1
    assert Set.member?(index.document_ids, doc.id)
    assert Map.size(index.terms) > 0
  end

  test "indexing custom doc" do
    my_doc = %{:id => 123,
      :field1 => "searchable field1",
      :_field2 => "not searchable cause _ prefix field2",
      "field3" => "searchable field3",
      "_field4" => "not searchable field4",
      :field5 => -1,
      :field6 => {"not", "searchable", "field6"}}
    {:ok, index} = Store.store(my_doc, "test-index2")

    assert Set.member?(index.document_ids, my_doc[:id])
    assert Map.size(index.terms) > 0
    assert Search.search(%TermQuery{value: "field1"}, [index.name]).hits |> ids == [123]
    assert Search.search(%TermQuery{value: "field2"}, [index.name]).hits |> ids == []
    assert Search.search(%TermQuery{value: "field3"}, [index.name]).hits |> ids == [123]
    assert Search.search(%TermQuery{value: "field4"}, [index.name]).hits |> ids == []
    assert Search.search(%TermQuery{value: "field5"}, [index.name]).hits |> ids == []
    assert Search.search(%TermQuery{value: "field6"}, [index.name]).hits |> ids == []
  end

  test "search for all docs" do
    idx = %Index{name: "all-q",
      document_ids: Set.put(HashSet.new, 0),
      terms: %{"foo" => %{0 => [%Location{field: :body, position: 0}]}}}
    
    doc = Indexer.test_corpus |> hd
    Documentstore.put(doc.id, doc)
    Indexstore.put(idx)
    result = Search.search(%MatchAll{}, [idx.name])

    assert length(result.hits) == 1
    assert result.hits |> ids |> Enum.member?(0)
  end

  test "search for specific term" do
    result = Search.search(%TermQuery{fields: [:title], value: "Pojke"}, ["test-index"])
    assert length(result.hits) == 1
    assert result.hits |> ids == [3]
  end

  test "search for term with multiple hits" do
    result = Search.search(%TermQuery{fields: [:body], value: "att"},
      ["foo", "test-index"])
    assert length(result.hits) > 1
    assert result.hits |> ids |> Enum.sort == [0, 1, 2]
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

  test "boolean query ORs" do
    q1 = %TermQuery{value: "tempo"}
    q2 = %TermQuery{value: "döda"}
    r = Search.search(%BooleanQuery{optional: [q1, q2]},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [1, 2]
  end

  test "boolean query ANDs" do
    q1 = %TermQuery{value: "det"}
    q2 = %TermQuery{value: "att"}
    r = Search.search(%BooleanQuery{must: [q1, q2]},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [0, 1]
  end

  test "boolean query ORs and ANDs" do
    opt = [%TermQuery{value: "tempo"}, %TermQuery{value: "döda"}]
    must = [%TermQuery{value: "det"}, %TermQuery{value: "att"}]
    r = Search.search(%BooleanQuery{optional: opt, must: must},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [0, 1] # TODO 1 should have higher ranking!
  end

  test "boolean query NOTs" do
    q1 = %TermQuery{value: "cedrik"}
    q2 = %TermQuery{value: "döda"}
    r = Search.search(%BooleanQuery{must_not: [q1, q2]},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [0, 1, 3]
  end

  test "boolean query NOTs + ANDs" do
    nope = [%TermQuery{value: "efter", fields: [:title]}]
    yep = [%TermQuery{value: "efter", fields: [:body]}]
    r = Search.search(%BooleanQuery{must: yep, must_not: nope},
      ["test-index"])
    assert r.hits |> ids == [1]
  end

  test "nested stuff" do
    have = [%BooleanQuery{
      optional: [%TermQuery{value: "cedrik"},
          %TermQuery{value: "Torslandafabriken"}]},
        %TermQuery{value: "a"}]

    r = Search.search(%BooleanQuery{must: have},
      ["test-index"])

    assert r.hits |> ids |> Enum.sort == [42, 666]
  end

  # TODO: Test (and impl) ranking!

  def ids(hits) when is_list(hits) do
    hits |> Enum.map(fn({id, _}) -> id end)
  end

  def ids(hits) do
    hits |> Enum.map(fn(d) -> Store.id(d) end)
  end
  #def ids(hits) when is_list(hits) do hits end
end

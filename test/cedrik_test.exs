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
    assert Search.search(%Query.Term{value: "field1"}, [index.name]).hits
      |> ids == [123]
    assert Search.search(%Query.Term{value: "field2"}, [index.name]).hits
      |> ids == []
    assert Search.search(%Query.Term{value: "field3"}, [index.name]).hits
      |> ids == [123]
    assert Search.search(%Query.Term{value: "field4"}, [index.name]).hits
      |> ids == []
    assert Search.search(%Query.Term{value: "field5"}, [index.name]).hits
      |> ids == []
    assert Search.search(%Query.Term{value: "field6"}, [index.name]).hits
      |> ids == []
  end

  test "search for all docs" do
    idx = %Index{name: "all-q",
      document_ids: Set.put(HashSet.new, 0),
      terms: %{"foo" => %{0 => [%Location{field: :body, position: 0}]}}}
    
    doc = Indexer.test_corpus |> hd
    Documentstore.put(doc.id, doc)
    Indexstore.put(idx)
    result = Search.search(%Query.MatchAll{}, [idx.name])

    assert length(result.hits) == 1
    assert result.hits |> ids |> Enum.member?(0)
  end

  test "search for specific term" do
    result = Search.search(%Query.Term{fields: [:title], value: "Pojke"},
      ["test-index"])
    assert length(result.hits) == 1
    assert result.hits |> ids == [3]
  end

  test "on_fields" do
    locs = [%Location{field: :body, position: 1},
            %Location{field: :title, position: 1}]
      |> Enum.into(HashSet.new)
    r = Query.Term.on_fields(locs, [:title])
      |> Enum.to_list
    assert hd(r).field == :title
  end

  test "search for term with multiple hits" do
    result = Search.search(%Query.Term{fields: [:body], value: "att"},
      ["foo", "test-index"])
    assert length(result.hits) > 1
    assert result.hits |> ids |> Enum.sort == [0, 1, 2]
  end

  test "term query obeys field parameter" do
    result = Search.search(%Query.Term{fields: [:body], value: "cedrik"},
      ["test-index"])
    assert result.hits |> ids == [42]
  end

  test "term query on many fields" do
    r = Search.search(%Query.Term{fields: [:title, :body], value: "cedrik"},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [42, 666]
  end

  test "term query without fields looks at all" do
    r = Search.search(%Query.Term{fields: [], value: "cedrik"},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [42, 666]
  end

  test "boolean query ORs" do
    q1 = %Query.Term{value: "tempo"}
    q2 = %Query.Term{value: "döda"}
    r = Search.search(%Query.Boolean{optional: [q1, q2]},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [1, 2]
  end

  test "boolean query ANDs" do
    q1 = %Query.Term{value: "det"}
    q2 = %Query.Term{value: "att"}
    r = Search.search(%Query.Boolean{must: [q1, q2]},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [0, 1]
  end

  test "boolean query ORs and ANDs" do
    opt = [%Query.Term{value: "tempo"}, %Query.Term{value: "döda"}]
    must = [%Query.Term{value: "det"}, %Query.Term{value: "att"}]
    r = Search.search(%Query.Boolean{optional: opt, must: must},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [0, 1] # TODO 1 should have higher ranking!
  end

  test "boolean query NOTs" do
    q1 = %Query.Term{value: "cedrik"}
    q2 = %Query.Term{value: "döda"}
    r = Search.search(%Query.Boolean{must_not: [q1, q2]},
      ["test-index"])
    assert r.hits |> ids |> Enum.sort == [0, 1, 3]
  end

  test "boolean query NOTs + ANDs" do
    nope = [%Query.Term{value: "efter", fields: [:title]}]
    yep = [%Query.Term{value: "efter", fields: [:body]}]
    r = Search.search(%Query.Boolean{must: yep, must_not: nope},
      ["test-index"])
    assert r.hits |> ids == [1]
  end

  test "nested stuff" do
    have = [%Query.Boolean{
      optional: [%Query.Term{value: "cedrik"},
          %Query.Term{value: "Torslandafabriken"}]},
        %Query.Term{value: "a"}]

    r = Search.search(%Query.Boolean{must: have},
      ["test-index"])

    assert r.hits |> ids |> Enum.sort == [42, 666]
  end

  test "ending wildcard query" do
    r = Search.search(%Query.Wildcard{fields: [:title], value: "Student*"},
      ["test-index"])
    assert r.hits |> ids == [0]
    assert r.hits |> locations == [:title]
  end

  test "leading wildcard query" do
    r = Search.search(%Query.Wildcard{fields: [:title], value: "*fabriken"},
      ["test-index"])
    assert r.hits |> ids == [1]
    assert r.hits |> locations == [:title]
  end

  # TODO: Test (and impl) ranking!

  def ids(hits) when is_list(hits) do
    hits |> Enum.map(fn({id, _}) -> id end)
  end

  def locations(hits) do
    hits
      |> Enum.flat_map(fn{_, locs} -> Set.to_list(locs) end)
      |> Enum.map(fn(l) -> l.field end)
      |> Enum.uniq
  end
end

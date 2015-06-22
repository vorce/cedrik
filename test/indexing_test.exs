defmodule IndexingTest do
  use ExUnit.Case, async: true
  use TestUtils

  setup_all do
    Indexstore.start_link()
    Documentstore.start_link()
    :ok
  end

  test "indexing one doc" do
    index_name = "index1"
    doc = hd(TestUtils.test_corpus)
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

  test "delete index" do
    idx = %Index{name: "cedrekked",
      document_ids: Set.put(HashSet.new, 0),
      terms: %{"foo" => %{0 => [%Location{field: :body, position: 0}]}}}
    Indexstore.put(idx)
    Indexstore.delete(idx.name)
    assert Indexstore.get(idx.name).document_ids |> Set.size == 0
    assert Indexstore.get(idx.name).terms |> Map.keys == []
  end

  test "delete doc" do
    index = "test-index-delete"
    doc1 = %{:id => 90_000,
      :text => "hello foo bar att en dag få vara cedrik term i nattens"}
    doc2 = %{:id => 91_000,
      :text => "nattens i term cedrik vara få dag en att bar foo hello"}

    Store.store(doc1, index)
    Store.store(doc2, index)

    assert Indexstore.get(index).document_ids
      |> Enum.member?(doc1.id)
    assert Indexstore.get(index).terms |> Map.get("cedrik")
      |> Map.has_key?(doc1.id)

    Store.delete(doc1, index)

    assert Indexstore.get(index).document_ids |> Enum.member?(doc2.id)
    assert Indexstore.get(index).document_ids |> Set.size == 1
    assert Indexstore.get(index).terms
      |> Map.get("cedrik") |> Map.keys == [doc2.id]
  end
end

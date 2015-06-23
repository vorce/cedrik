defmodule AgentIndexTest do
  use ExUnit.Case #, async: true
  use TestUtils

  setup_all do
    AgentIndex.start_link()
    Application.put_env(:index, :backend, AgentIndex)
    :ok
  end

  test "indexing one doc" do
    index_name = "index1"
    doc = hd(TestUtils.test_corpus)
    :ok = AgentIndex.index(doc, index_name)
    index = AgentIndex.get(index_name)

    assert index.name == index_name
    assert index.document_ids |> Set.size() == 1
    assert Set.member?(index.document_ids, Store.id(doc))
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
    :ok = AgentIndex.index(my_doc, "test-index2")
    index = AgentIndex.get("test-index2")

    assert Set.member?(index.document_ids, Store.id(my_doc))
    assert Map.size(index.terms) > 0
    assert Search.search(%Query.Term{value: "field1"}, [index.name]).hits
      |> ids == ["123"]
    assert Search.search(%Query.Term{value: "field2"}, [index.name]).hits
      |> ids == []
    assert Search.search(%Query.Term{value: "field3"}, [index.name]).hits
      |> ids == ["123"]
    assert Search.search(%Query.Term{value: "field4"}, [index.name]).hits
      |> ids == []
    assert Search.search(%Query.Term{value: "field5"}, [index.name]).hits
      |> ids == []
    assert Search.search(%Query.Term{value: "field6"}, [index.name]).hits
      |> ids == []
  end

  test "delete index" do
    idx = %AgentIndex{name: "cedrekked",
      document_ids: Set.put(HashSet.new, 0),
      terms: %{"foo" => %{0 => [%Location{field: :body, position: 0}]}}}
    AgentIndex.put(idx)
    AgentIndex.delete(idx.name)
    assert AgentIndex.document_ids(idx.name) |> Set.size == 0
    assert AgentIndex.terms(idx.name) |> Enum.to_list == []
  end

  test "delete doc" do
    index = "test-index-delete"
    doc1 = %{:id => 90_000,
      :text => "hello foo bar att en dag få vara cedrik term i nattens"}
    doc2 = %{:id => 91_000,
      :text => "nattens i term cedrik vara få dag en att bar foo hello"}

    AgentIndex.index(doc1, index)
    AgentIndex.index(doc2, index)

    assert AgentIndex.document_ids(index)
      |> Enum.member?(Store.id(doc1))
    assert AgentIndex.term_positions("cedrik", index)
      |> Map.has_key?(Store.id(doc1))

    AgentIndex.delete_doc(Store.id(doc1), index)

    assert AgentIndex.document_ids(index) |> Enum.member?(Store.id(doc2))
    assert AgentIndex.document_ids(index) |> Set.size == 1
    assert AgentIndex.term_positions("cedrik", index)
      |> Map.keys == [Store.id(doc2)]
  end
end

defmodule AgentIndexTest do
  use ExUnit.Case #, async: true
  alias TestUtils

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
    index = "test-index2"
    my_doc = %{:id => 123,
      :field1 => "searchable field1",
      :_field2 => "not searchable cause _ prefix field2",
      "field3" => "searchable field3",
      "_field4" => "not searchable field4",
      :field5 => -1,
      :field6 => {"not", "searchable", "field6"}}

    :ok = AgentIndex.index(my_doc, index)

    assert Set.member?(AgentIndex.document_ids(index), Store.id(my_doc))
    assert AgentIndex.terms(index) |> Enum.to_list |> Enum.sort ==
      ["field1", "field3", "searchable"]
    tps = AgentIndex.term_positions("searchable", index)
    assert tps |> Map.get(AgentIndex.id(my_doc), HashSet.new) |> Set.size == 2
  end

  test "delete index" do
    doc = %{:id => 0, :body => "foo"}
    index = "agent_cedrekked"

    AgentIndex.index(doc, index)
    assert AgentIndex.document_ids(index) |> Set.size == 1
    assert AgentIndex.terms(index) |> Enum.to_list == ["foo"]

    AgentIndex.delete(index)

    assert AgentIndex.document_ids(index) |> Set.size == 0
    assert AgentIndex.terms(index) |> Enum.to_list == []
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

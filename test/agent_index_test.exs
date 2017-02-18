defmodule AgentIndexTest do
  use ExUnit.Case, async: true
  alias TestUtils

  setup do
    {:ok, idx} = AgentIndex.start_link([name: :test])
    {:ok, pid: idx}
  end

  test "indexing one doc", %{pid: pid} do
    doc = hd(TestUtils.test_corpus)
    :ok = AgentIndex.index(doc, pid)
    index = AgentIndex.get(pid)

    assert index.document_ids |> MapSet.size() == 1
    assert MapSet.member?(index.document_ids, Storable.id(doc))
    assert Map.size(index.terms) > 0
  end

  test "indexing custom doc", %{pid: pid} do
    my_doc = %{:id => 123,
      :field1 => "searchable field1",
      :_field2 => "not searchable cause _ prefix field2",
      "field3" => "searchable field3",
      "_field4" => "not searchable field4",
      :field5 => -1,
      :field6 => {"not", "searchable", "field6"}}

    :ok = AgentIndex.index(my_doc, pid)

    assert MapSet.member?(AgentIndex.document_ids(pid), Storable.id(my_doc))
    assert AgentIndex.terms(pid) |> Enum.to_list |> Enum.sort ==
      ["field1", "field3", "searchable"]
    tps = AgentIndex.term_positions("searchable", pid)
    assert tps |> Map.get(Storable.id(my_doc), MapSet.new) |> MapSet.size == 2
  end

  test "clear index", %{pid: pid} do
    doc = %{:id => 0, :body => "foo"}

    AgentIndex.index(doc, pid)
    assert AgentIndex.document_ids(pid) |> MapSet.size == 1
    assert AgentIndex.terms(pid) |> Enum.to_list == ["foo"]

    AgentIndex.clear(pid)

    assert AgentIndex.document_ids(pid) |> MapSet.size == 0
    assert AgentIndex.terms(pid) |> Enum.to_list == []
  end

  test "delete doc", %{pid: pid} do
    doc1 = %{:id => 90_000,
      :text => "hello foo bar att en dag få vara cedrik term i nattens"}
    doc2 = %{:id => 91_000,
      :text => "nattens i term cedrik vara få dag en att bar foo hello"}

    AgentIndex.index(doc1, pid)
    AgentIndex.index(doc2, pid)

    assert AgentIndex.document_ids(pid)
      |> Enum.member?(Storable.id(doc1))
    assert AgentIndex.term_positions("cedrik", pid)
      |> Map.has_key?(Storable.id(doc1))

    AgentIndex.delete_doc(Storable.id(doc1), pid)

    assert AgentIndex.document_ids(pid) |> Enum.member?(Storable.id(doc2))
    assert AgentIndex.document_ids(pid) |> MapSet.size == 1
    assert AgentIndex.term_positions("cedrik", pid)
      |> Map.keys == [Storable.id(doc2)]
  end
end

defmodule AgentIndexTest do
  use ExUnit.Case, async: true
  alias TestUtils

  @test_index_file "test_index.cedrik"

  setup do
    {:ok, idx} = AgentIndex.start_link(name: :test)

    on_exit(fn ->
      File.rm(@test_index_file)
    end)

    {:ok, pid: idx}
  end

  test "store and load to/from file", %{pid: pid} do
    doc = hd(TestUtils.test_corpus())
    :ok = AgentIndex.index(doc, pid)

    refute File.exists?(@test_index_file)
    assert AgentIndex.save_to_file(@test_index_file, pid) == :ok
    assert File.exists?(@test_index_file)

    {:ok, load} = AgentIndex.start_link(name: :test_load_from_file)
    refute MapSet.member?(AgentIndex.document_ids(load), Storable.id(doc))

    assert AgentIndex.load_from_file(@test_index_file, load) == :ok
    assert MapSet.member?(AgentIndex.document_ids(load), Storable.id(doc))
  end

  test "indexing one doc", %{pid: pid} do
    doc = hd(TestUtils.test_corpus())
    :ok = AgentIndex.index(doc, pid)
    index = AgentIndex.get(pid)

    assert MapSet.size(index.document_ids) == 1
    assert MapSet.member?(index.document_ids, Storable.id(doc))
    assert Map.size(index.terms) > 0
  end

  test "indexing custom doc", %{pid: pid} do
    my_doc = %{
      :id => 123,
      :field1 => "searchable field1",
      :_field2 => "not searchable cause _ prefix field2",
      "field3" => "searchable field3",
      "_field4" => "not searchable field4",
      :field5 => -1,
      :field6 => {"not", "searchable", "field6"}
    }

    :ok = AgentIndex.index(my_doc, pid)

    assert MapSet.member?(AgentIndex.document_ids(pid), Storable.id(my_doc))

    assert pid |> AgentIndex.terms() |> Enum.to_list() |> Enum.sort() ==
             ["field1", "field3", "searchable"]

    tps = AgentIndex.term_positions("searchable", pid)
    assert tps |> Map.get(Storable.id(my_doc), MapSet.new()) |> MapSet.size() == 2
  end

  test "clear index", %{pid: pid} do
    doc = %{:id => 0, :body => "foo"}

    AgentIndex.index(doc, pid)
    assert pid |> AgentIndex.document_ids() |> MapSet.size() == 1
    assert pid |> AgentIndex.terms() |> Enum.to_list() == ["foo"]

    AgentIndex.clear(pid)

    assert pid |> AgentIndex.document_ids() |> MapSet.size() == 0
    assert pid |> AgentIndex.terms() |> Enum.to_list() == []
  end

  test "delete doc", %{pid: pid} do
    doc1 = %{:id => 90_000, :text => "hello foo bar att en dag få vara cedrik term i nattens"}
    doc2 = %{:id => 91_000, :text => "nattens i term cedrik vara få dag en att bar foo hello"}

    AgentIndex.index(doc1, pid)
    AgentIndex.index(doc2, pid)

    assert pid
           |> AgentIndex.document_ids()
           |> Enum.member?(Storable.id(doc1))

    assert "cedrik"
           |> AgentIndex.term_positions(pid)
           |> Map.has_key?(Storable.id(doc1))

    AgentIndex.delete_doc(Storable.id(doc1), pid)

    assert pid |> AgentIndex.document_ids() |> Enum.member?(Storable.id(doc2))
    assert pid |> AgentIndex.document_ids() |> MapSet.size() == 1

    assert "cedrik"
           |> AgentIndex.term_positions(pid)
           |> Map.keys() == [Storable.id(doc2)]
  end
end

defmodule RedisIndexTest do
  use ExUnit.Case, async: true
  alias TestUtils

  @moduletag :external

  @test_index :redis_index

  setup_all do
    {:ok, pid} = Supervisor.start_child(IndexSupervisor,
      Supervisor.Spec.worker(RedisIndex, [[name: @test_index]], id: @test_index))
    {:ok, pid: pid}
  end

  setup %{pid: pid} do
     RedisIndex.clear(pid)
     :ok
  end

  test "indexing one doc", %{pid: pid} do
    doc = hd(TestUtils.test_corpus)

    RedisIndex.index(doc, pid)

    assert RedisIndex.document_ids(pid) |> MapSet.size() == 1
    assert RedisIndex.document_ids(pid) |> MapSet.member?(Storable.id(doc))
    assert RedisIndex.terms(pid) |> Enum.to_list |> length > 0
  end

  test "indexing custom doc", %{pid: pid} do
    my_doc = %{:id => 123,
      :field1 => "searchable field1",
      :_field2 => "not searchable cause _ prefix field2",
      "field3" => "searchable field3",
      "_field4" => "not searchable field4",
      :field5 => -1,
      :field6 => {"not", "searchable", "field6"}}
    :ok = RedisIndex.index(my_doc, pid)

    assert MapSet.member?(RedisIndex.document_ids(pid), Storable.id(my_doc))
    assert RedisIndex.terms(pid) |> Enum.to_list |> Enum.sort ==
      ["field1", "field3", "searchable"]
    tps = RedisIndex.term_positions("searchable", pid)
    assert tps |> Map.get(Storable.id(my_doc), MapSet.new) |> MapSet.size == 2
  end

  test "clear index", %{pid: pid} do
    doc = %{:id => 0, :body => "foo"}

    RedisIndex.index(doc, pid)
    assert RedisIndex.document_ids(pid) |> MapSet.size == 1
    assert RedisIndex.terms(pid) |> Enum.to_list == ["foo"]

    RedisIndex.clear(pid)

    assert RedisIndex.document_ids(pid) |> MapSet.size == 0
    assert RedisIndex.terms(pid) |> Enum.to_list == []
  end

  # test "delete old terms", %{pid: pid} do
  #   doc1 = %{:id => 93_000,
  #     :text => "hello foo bar att en dag få vara cedrik term i nattens"}
  #
  #   RedisIndex.index(doc1, pid)
  #
  #   assert RedisIndex.term_positions("cedrik", pid) |> Map.has_key?(Storable.id(doc1))
  #
  #   RedisIndex.delete_old_terms(["cedrik"], Storable.id(doc1), pid)
  #   assert RedisIndex.term_positions("cedrik", pid) == %{}
  # end

  test "delete doc", %{pid: pid} do
    doc1 = %{:id => 90_000,
      :text => "hello foo bar att en dag få vara cedrik term i nattens"}
    doc2 = %{:id => 91_000,
      :text => "nattens i term cedrik vara få dag en att bar foo hello"}

    RedisIndex.index(doc1, pid)
    RedisIndex.index(doc2, pid)

    assert RedisIndex.document_ids(pid)
      |> Enum.member?(Storable.id(doc1))
    assert RedisIndex.term_positions("cedrik", pid)
      |> Map.has_key?(Storable.id(doc1))

    RedisIndex.delete_doc(Storable.id(doc1), pid)

    assert RedisIndex.document_ids(pid) |> Enum.member?(Storable.id(doc2))
    assert RedisIndex.document_ids(pid) |> MapSet.size == 1

    assert RedisIndex.term_positions("cedrik", pid)
      |> Map.keys == [Storable.id(doc2)]
  end
end

defmodule RedisIndexTest do
  use ExUnit.Case #, async: true
  alias TestUtils

  @moduletag :external

  setup_all do
    Application.put_env(:index, :backend, RedisIndex) # TODO fix so we can enable async
    :ok
  end

  test "indexing one doc" do
    index_name = "redis_index1"
    doc = hd(TestUtils.test_corpus)

    RedisIndex.index(doc, index_name)

    assert RedisIndex.indices() |> Enum.member?(index_name)
    assert RedisIndex.document_ids(index_name) |> Set.size() == 1
    assert RedisIndex.document_ids(index_name) |> Set.member?(Store.id(doc))
    assert RedisIndex.terms(index_name) |> Enum.to_list |> length > 0
  end

  test "indexing custom doc" do
    index = "redis-index2"
    my_doc = %{:id => 123,
      :field1 => "searchable field1",
      :_field2 => "not searchable cause _ prefix field2",
      "field3" => "searchable field3",
      "_field4" => "not searchable field4",
      :field5 => -1,
      :field6 => {"not", "searchable", "field6"}}
    :ok = RedisIndex.index(my_doc, index)

    assert Set.member?(RedisIndex.document_ids(index), Store.id(my_doc))
    assert RedisIndex.terms(index) |> Enum.to_list |> Enum.sort ==
      ["field1", "field3", "searchable"]
    tps = RedisIndex.term_positions("searchable", index)
    assert tps |> Map.get(RedisIndex.id(my_doc), HashSet.new) |> Set.size == 2
  end

  test "delete index" do
    doc = %{:id => 0, :body => "foo"}
    index = "agent_cedrekked"

    RedisIndex.index(doc, index)
    assert RedisIndex.document_ids(index) |> Set.size == 1
    assert RedisIndex.terms(index) |> Enum.to_list == ["foo"]

    RedisIndex.delete(index)

    assert RedisIndex.document_ids(index) |> Set.size == 0
    assert RedisIndex.terms(index) |> Enum.to_list == []
  end

  test "delete old terms" do
    index = "test-index-delete2"
    doc1 = %{:id => 93_000,
      :text => "hello foo bar att en dag få vara cedrik term i nattens"}

    RedisIndex.index(doc1, index)

    assert RedisIndex.term_positions("cedrik", index) |> Map.has_key?(Store.id(doc1))

    RedisIndex.delete_old_terms(["cedrik"], Store.id(doc1), index)
    assert RedisIndex.term_positions("cedrik", index) == %{}
  end

  test "delete doc" do
    index = "test-index-delete"
    doc1 = %{:id => 90_000,
      :text => "hello foo bar att en dag få vara cedrik term i nattens"}
    doc2 = %{:id => 91_000,
      :text => "nattens i term cedrik vara få dag en att bar foo hello"}

    RedisIndex.index(doc1, index)
    RedisIndex.index(doc2, index)

    assert RedisIndex.document_ids(index)
      |> Enum.member?(Store.id(doc1))
    assert RedisIndex.term_positions("cedrik", index)
      |> Map.has_key?(Store.id(doc1))

    RedisIndex.delete_doc(Store.id(doc1), index)

    assert RedisIndex.document_ids(index) |> Enum.member?(Store.id(doc2))
    assert RedisIndex.document_ids(index) |> Set.size == 1

    assert RedisIndex.term_positions("cedrik", index)
      |> Map.keys == [Store.id(doc2)]
  end
end

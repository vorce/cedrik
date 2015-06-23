defmodule RedisIndexTest do
  use ExUnit.Case #, async: true
  use TestUtils

  @moduletag :external

  # Exclude all external tests from running.
  # TODO move to somewhere more suitable
  ExUnit.configure(exclude: [external: true])

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
    assert RedisIndex.terms(index) |> Enum.to_list |> length > 0
    assert Search.search(%Query.Term{value: "field1"}, [index]).hits
      |> ids == ["123"]
    assert Search.search(%Query.Term{value: "field2"}, [index]).hits
      |> ids == []
    assert Search.search(%Query.Term{value: "field3"}, [index]).hits
      |> ids == ["123"]
    assert Search.search(%Query.Term{value: "field4"}, [index]).hits
      |> ids == []
    assert Search.search(%Query.Term{value: "field5"}, [index]).hits
      |> ids == []
    assert Search.search(%Query.Term{value: "field6"}, [index]).hits
      |> ids == []
  end
end
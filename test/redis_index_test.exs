defmodule RedisIndexTest do
  use ExUnit.Case, async: true
  use TestUtils

  @moduletag :external

  # Exclude all external tests from running.
  # TODO move to somewhere more suitable
  ExUnit.configure(exclude: [external: true])

  setup_all do
    AgentStore.start_link()
    :ok
  end

  test "indexing one doc" do
    index_name = "redis_index1"
    doc = hd(TestUtils.test_corpus)
    
    RedisIndex.index(Store.id(doc), doc, index_name)
    
    assert RedisIndex.indices() |> Enum.member?(index_name)
    assert RedisIndex.document_ids(index_name) |> length == 1
    assert RedisIndex.document_ids(index_name) |> Enum.member?(Store.id(doc))
    assert RedisIndex.terms(index_name) |> Enum.to_list |> length > 0
  end

  """
  test "indexing custom doc" do
    index = "redis_index2"
    my_doc = %{:id => 123,
      :field1 => "searchable field1",
      :_field2 => "not searchable cause _ prefix field2",
      "field3" => "searchable field3",
      "_field4" => "not searchable field4",
      :field5 => -1,
      :field6 => {"not", "searchable", "field6"}}

    RedisIndex.index(Store.id(my_doc), doc, index_name)


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
  """
end
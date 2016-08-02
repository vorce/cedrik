defmodule E2eTest do
  use ExUnit.Case, async: true

  @moduletag :external

  test "index and search" do
    doc1 = hd(TestUtils.test_corpus())
    doc2 = Enum.at(TestUtils.test_corpus(), 1)
    :ok = Index.index_doc(doc1, :my_agent_index)
    :ok = Index.index_doc(doc2, :my_redis_index)
    query = %Query.Boolean{
      must: [%Query.Term{value: "och"}],
      optional: [%Query.Wildcard{value: "Torslanda*"}],
      must_not: [%Query.Wildcard{value: "*olvo"}]
    }

    result = Search.search(query, [:my_agent_index, :my_redis_index])

    assert length(result.hits) == 1
    assert result.hits |> TestUtils.ids |> Enum.sort == ["0"]
  end

  test "index and search with string" do
    doc1 = hd(TestUtils.test_corpus())
    :ok = Index.index_doc(doc1, :hello_world)
    query = Query.Parse.parse("bygge Majorna")

    result = Search.search(query, [:hello_world])

    assert length(result.hits) == 1
    assert result.hits |> TestUtils.ids |> Enum.sort == ["0"]
  end

  test "remove index" do
     doc1 = hd(TestUtils.test_corpus())
     :ok = Index.index_doc(doc1, :my_agent_index2)
     details = IndexSupervisor.by_name(:my_agent_index2)

     assert IndexSupervisor.list |> Enum.member?(details) == true

     :ok = IndexSupervisor.remove(details)

     assert IndexSupervisor.list |> Enum.member?(details) == false
  end
end

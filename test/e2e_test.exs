defmodule E2eTest do
  use ExUnit.Case, async: true

  @moduletag :external

  test "index and search" do
    doc1 = hd(TestUtils.test_corpus())
    doc2 = Enum.at(TestUtils.test_corpus(), 1)
    :ok = Index.index_doc(doc1, :my_agent_index)
    :ok = Index.index_doc(doc2, :my_redis_index)

    result = Search.search(%Query.MatchAll{}, [:my_agent_index, :my_redis_index])

    assert length(result.hits) == 2
    assert result.hits |> TestUtils.ids |> Enum.sort == ["0", "1"]
  end
end

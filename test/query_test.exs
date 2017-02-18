defmodule QueryTest do
  use ExUnit.Case, async: true
  alias TestUtils, as: T

  @test_index :test_index

  setup_all do
    {:ok, pid} = T.setup_corpus(@test_index)
    {:ok, pid: pid}
  end

  test "search for all docs" do
    {:ok, pid} = Supervisor.start_child(IndexSupervisor,
      Supervisor.Spec.worker(AgentIndex, [[name: :all_q]]))

    idx = %CedrikIndex{name: :all_q,
      document_ids: MapSet.put(MapSet.new, "0"),
      terms: %{"foo" => %{0 => [%Location{field: :body, position: 0}]}}}

    AgentIndex.put(idx, pid)
    result = Search.search(%Query.MatchAll{}, [idx.name])

    assert length(result.hits) == 1
    assert result.hits |> T.ids() |> Enum.member?("0")
    assert result.hits |> T.locations() |> length() == 0
  end

  test "search for specific term" do
    result = Search.search(%Query.Term{fields: [:title], value: "Pojke"},
      [@test_index])
    assert T.ids(result.hits) == ["3"]
  end

  test "on_fields" do
    locs = Enum.into(
      [%Location{field: :body, position: 1},
        %Location{field: :title, position: 1}],
      MapSet.new
    )

    r = locs
    |> Query.Term.on_fields([:title])
    |> Enum.to_list

    assert hd(r).field == :title
  end

  test "search for term with multiple hits" do
    result = Search.search(%Query.Term{fields: [:body], value: "att"},
      [:foo, @test_index])
    assert result.hits |> T.ids() |> Enum.sort() == ["0", "1", "2"]
  end

  test "term query obeys field parameter" do
    result = Search.search(%Query.Term{fields: [:body], value: "cedrik"},
      [@test_index])
    assert T.ids(result.hits) == ["42"]
  end

  test "term query on many fields" do
    r = Search.search(%Query.Term{fields: [:title, :body], value: "cedrik"},
      [@test_index])
    assert r.hits |> T.ids() |> Enum.sort() == ["42", "666"]
  end

  test "term query without fields looks at all" do
    r = Search.search(%Query.Term{fields: [], value: "cedrik"},
      [@test_index])
    assert r.hits |> T.ids() |> Enum.sort() == ["42", "666"]
  end

  test "boolean query ORs" do
    q1 = %Query.Term{value: "tempo"}
    q2 = %Query.Term{value: "döda"}
    r = Search.search(%Query.Boolean{optional: [q1, q2]},
      [@test_index])
    assert r.hits |> T.ids() |> Enum.sort() == ["1", "2"]
  end

  test "boolean query ANDs" do
    q1 = %Query.Term{value: "det"}
    q2 = %Query.Term{value: "att"}
    r = Search.search(%Query.Boolean{must: [q1, q2]},
      [@test_index])
    assert r.hits |> T.ids() |> Enum.sort() == ["0", "1"]
  end

  test "boolean query ORs and ANDs" do
    opt = [%Query.Term{value: "tempo"}, %Query.Term{value: "döda"}]
    must = [%Query.Term{value: "det"}, %Query.Term{value: "att"}]
    r = Search.search(%Query.Boolean{optional: opt, must: must},
      [@test_index])
    assert r.hits |> T.ids() |> Enum.sort() == ["0", "1"] # TODO 1 should have higher ranking!
  end

  test "boolean query NOTs" do
    q1 = %Query.Term{value: "cedrik"}
    q2 = %Query.Term{value: "döda"}
    r = Search.search(%Query.Boolean{must_not: [q1, q2]},
      [@test_index])
    assert r.hits |> T.ids() |> Enum.sort() == ["0", "1", "3"]
  end

  test "boolean query NOTs + ANDs" do
    nope = [%Query.Term{value: "efter", fields: [:title]}]
    yep = [%Query.Term{value: "efter", fields: [:body]}]
    r = Search.search(%Query.Boolean{must: yep, must_not: nope},
      [@test_index])
    assert T.ids(r.hits) == ["1"]
  end

  test "nested stuff" do
    have = [%Query.Boolean{
      optional: [%Query.Term{value: "cedrik"},
          %Query.Term{value: "Torslandafabriken"}]},
        %Query.Term{value: "a"}]

    r = Search.search(%Query.Boolean{must: have},
      [@test_index])

    assert r.hits |> T.ids() |> Enum.sort() == ["42", "666"]
  end

  test "ending wildcard query" do
    r = Search.search(%Query.Wildcard{fields: [:title], value: "Student*"},
      [@test_index])
    assert T.ids(r.hits) == ["0"]
    assert T.locations(r.hits) == [:title]
  end

  test "leading wildcard query" do
    r = Search.search(%Query.Wildcard{fields: [:title], value: "*fabriken"},
      [@test_index])
    assert T.ids(r.hits) == ["1"]
    assert T.locations(r.hits) == [:title]
  end

  test "wildcard with no hits" do
    wild =  %Query.Wildcard{value: "*jasdklsajd"}

    r = Search.search(wild, [@test_index])

    assert r.hits == []
  end

  test "boolean with wildcards" do
    wild_pre = %Query.Wildcard{value: "*virus"}
    wild_post = %Query.Wildcard{value: "calici*"}
    bool_query = %Query.Boolean{optional: [wild_pre, wild_post]}

    r = Search.search(bool_query, [@test_index])

    assert r.hits |> T.ids() |> Enum.sort() == ["2"]
  end

  test "ids with more hits before ids with less hits" do
    r = Search.search(%Query.Term{value: "en"}, [@test_index])

    assert length(r.hits) > 1
    assert r.hits |> T.ids() |> hd() == "3"
  end
end

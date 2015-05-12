defmodule Index do
  @derive [Access]
  defstruct name: "index1", document_ids: HashSet.new, terms: Map.new
  @type t :: %Index{name: String.t, document_ids: Set.t, terms: Map.t}
  # Terms look like: %{"word1" => %{docId1 => [pos1, pos2], docId2 => [pos3]}, "word2" => %{...}}
end

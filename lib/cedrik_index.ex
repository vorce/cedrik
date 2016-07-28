defmodule CedrikIndex do
  defstruct name: :index1, document_ids: HashSet.new, terms: Map.new, type: :agent
  @type t :: %CedrikIndex{name: Atom.t, document_ids: Set.t, terms: Map.t, type: Atom.t}
  # Terms look like: %{"word1" => %{docId1 => [pos1, pos2], docId2 => [pos3]}, "word2" => %{...}}
end

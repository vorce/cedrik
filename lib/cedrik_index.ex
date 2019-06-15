defmodule CedrikIndex do
  @moduledoc """
  Data structure representing an index in cedrik
  """

  defstruct name: :index1, document_ids: MapSet.new(), terms: Map.new(), type: :agent
  @type t :: %CedrikIndex{name: Atom.t(), document_ids: MapSet.t(), terms: Map.t(), type: Atom.t()}
  # Terms look like: %{"word1" => %{docId1 => [pos1, pos2], docId2 => [pos3]}, "word2" => %{...}}
end

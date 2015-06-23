defmodule AgentIndex do
  @moduledoc """
  In-memory index
  """

  @derive [Access]
  defstruct name: "index1", document_ids: HashSet.new, terms: Map.new
  @type t :: %AgentIndex{name: String.t, document_ids: Set.t, terms: Map.t}
  # Terms look like: %{"word1" => %{docId1 => [pos1, pos2], docId2 => [pos3]}, "word2" => %{...}}

  @doc """
  Starts a new AgentIndex which stores index info in an Agent.
  """
  def start_link do
    Agent.start_link(fn -> Map.new end, name: __MODULE__)
  end

  @doc """
  Gets a value by `key`. If it doesn't exist
  creates a new index.
  """
  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key, %AgentIndex{name: key}))
  end

  @doc """
  Puts the `value` for the given `key`
  """
  def put(index) do
    Agent.update(__MODULE__, &Map.put(&1, index.name, index))
  end

  @doc """
  Deletes the index
  """
  def delete(key) do
    Agent.update(__MODULE__, &Map.drop(&1, [key]))
  end

  @doc """
  Deletes the terms and id of the doc in the index
  """
  def delete_doc(doc, index_name) do
    did = Store.id(doc)
    IO.puts("Deleting document #{did} from index #{index_name}")

    doc_ids = get(index_name).document_ids
      |> Stream.reject(fn(x) -> x == did end)

    mod_terms = get(index_name).terms
      |> Stream.filter(fn({_term, pos}) -> Map.has_key?(pos, did) end)
      |> Stream.map(fn({term, pos}) ->
          {term, Map.drop(pos, [did])}
        end)
      |> Enum.into(%{})

    get(index_name)
      |> update_in([:document_ids], fn(_ids) ->
        doc_ids |> Enum.into(HashSet.new) end)
      |> update_in([:terms], fn(x) ->
          Map.merge(x, mod_terms)
        end)
      |> put
  end
end


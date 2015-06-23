defmodule AgentIndex do
  @moduledoc """
  In-memory index
  """
  @behaviour Indexer

  @derive [Access]
  defstruct name: "index1", document_ids: HashSet.new, terms: Map.new, type: :agent
  @type t :: %AgentIndex{name: String.t, document_ids: Set.t, terms: Map.t, type: Atom.t}
  # Terms look like: %{"word1" => %{docId1 => [pos1, pos2], docId2 => [pos3]}, "word2" => %{...}}

  def index(doc, index) do
    id = id(doc)
    terms = Indexer.field_locations(id, doc)
      |> Enum.reduce(&Indexer.merge_term_locations(&1, &2))

    idx = get(index)
      |> update_in([:terms], fn(ts) -> Indexer.merge_term_locations(ts, terms) end)
      |> update_in([:document_ids], fn(ids) -> Set.put(ids, id) end)
    
    put(idx)
  end

  def id(thing) do
    Store.id(thing)
  end

  def indices() do
    Agent.get(__MODULE__, &Map.keys(&1))
  end

  def term_positions(term, index) do
    get(index).terms
      |> Map.get(term, %{})
  end

  def terms(index) do
    get(index).terms
      |> Map.keys
      |> Stream.map(fn(t) -> t end)
  end

  def document_ids(index) do
    get(index).document_ids
  end

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
  def delete_doc(did, index_name) do
    IO.puts("Deleting document #{did} from index #{index_name}")

    doc_ids = document_ids(index_name)
      |> Stream.reject(fn(x) -> x == did end)

    mod_terms = terms(index_name)
      |> Stream.map(fn(t) -> {t, term_positions(t, index_name)} end)
      |> Stream.filter(fn({_t, pos}) -> Map.has_key?(pos, did) end)
      |> Stream.map(fn({t, pos}) ->
          {t, Map.drop(pos, [did])}
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


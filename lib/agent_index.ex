defmodule AgentIndex do
  @moduledoc """
  In-memory index
  """

  @behaviour Index
  require Logger

  def index(doc, pid) do
    id = Storable.id(doc)

    terms = id
    |> Index.field_locations(doc)
    |> Enum.reduce(&Index.merge_term_locations(&1, &2))

    pid
    |> get()
    |> Map.update(:terms, %{}, fn(ts) -> Index.merge_term_locations(ts, terms) end)
    |> Map.update(:document_ids, MapSet.new, fn(ids) -> MapSet.put(ids, id) end)
    |> put(pid)
  end

  def term_positions(term, pid) do
    Map.get(get(pid).terms, term, %{})
  end

  def terms(pid) do
    get(pid).terms
    |> Map.keys()
    |> Stream.map(fn(t) -> t end)
  end

  def document_ids(pid) do
    get(pid).document_ids
  end

  @doc """
  Starts a new AgentIndex which stores index info in an Agent.
  """
  def start_link(opts \\ []) do
    Agent.start_link(fn -> %CedrikIndex{name: Keyword.get(opts, :name)} end, opts)
  end

  @doc """
  Gets a value by `key`. If it doesn't exist
  creates a new index.
  """
  def get(pid) do
    Agent.get(pid, &(&1))
  end

  @doc """
  Puts the `value` for the given `key`
  """
  def put(index, pid) do
    Agent.update(pid, fn(_) -> index end)
  end

  @doc """
  Clear the index
  """
  def clear(pid) do
    Agent.get_and_update(pid,
      fn(i) -> {i, %CedrikIndex{i | document_ids: MapSet.new, terms: Map.new}} end)
  end

  @doc """
  Deletes the terms and id of the doc in the index
  """
  def delete_doc(did, pid) do
    Logger.debug("Deleting document #{did} from index #{inspect pid}")

    doc_ids = pid
    |> document_ids()
    |> Stream.reject(fn(x) -> x == did end)

    mod_terms = pid
    |> terms()
    |> Stream.map(fn(t) -> {t, term_positions(t, pid)} end)
    |> Stream.filter(fn({_t, pos}) -> Map.has_key?(pos, did) end)
    |> Stream.map(fn({t, pos}) ->
        {t, Map.drop(pos, [did])}
      end)
    |> Enum.into(%{})

    pid
    |> get()
    |> Map.update(:document_ids, MapSet.new, fn(_ids) ->
      Enum.into(doc_ids, MapSet.new)
    end)
    |> Map.update(:terms, %{}, fn(x) ->
      Map.merge(x, mod_terms)
    end)
    |> put(pid)
  end
end

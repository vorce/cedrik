defmodule RedisIndex do
  @moduledoc """
  Redis as a backend for cedrik indices
  """
  use GenServer
  require Logger

  @behaviour Index

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  def init(opts) do
    {:ok, %CedrikIndex{name: Keyword.get(opts, :name), type: :redis}}
  end

  def index(thing, index) do
    GenServer.call(index, {:index, thing})
  end

  def clear(index) do
    GenServer.call(index, :clear)
  end

  def delete_doc(docid, index) do
    GenServer.call(index, {:delete_doc, docid})
  end

  def terms(index) do
    GenServer.call(index, :terms)
  end

  def term_positions(term, index) do
    GenServer.call(index, {:term_positions, term})
  end

  def document_ids(index) do
    GenServer.call(index, :document_ids)
  end

  def get(index) do
    GenServer.call(index, :get)
  end

  defp redis() do
    elem(Exredis.start_link(), 1)
  end

  def handle_call({:index, data}, _from, state) do
    {:reply, _index(data, state.name), state}
  end

  def handle_call(:terms, _from, state) do
    {:reply, _terms(state.name), state}
  end

  def handle_call(:document_ids, _from, state) do
    {:reply, _document_ids(state.name), state}
  end

  def handle_call(:clear, _from, state) do
    {:reply, _clear(state.name), state}
  end

  def handle_call({:term_positions, term}, _from, state) do
    {:reply, _term_positions(term, state.name), state}
  end

  def handle_call({:delete_doc, docid}, _from, state) do
    {:reply, _delete_doc(docid, state.name), state}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def indices() do
    Exredis.query(redis(), ["SMEMBERS", ".indices"])
  end

  def _document_ids(index) do
    redis()
    |> Exredis.query(["SMEMBERS", "#{index}.document_ids"])
    |> Enum.into(MapSet.new())

    # |> Stream.map(fn(id) -> id end)
  end

  def _terms(index) do
    redis()
    |> Exredis.query(["SMEMBERS", "#{index}.terms"])
    |> Stream.map(fn t -> t end)
  end

  @doc """
  Returns a map of positions for each document where the term exist. Ex:
  %{"docId123" => [pos1, pos2], "docIdN" => [pos1]}
  """
  def _term_positions(term, index) do
    redis()
    |> Exredis.query(["SMEMBERS", "#{index}_#{term}"])
    # [%{"3" => [%{"field" => "title", "position" => 0}]}]
    |> Stream.map(&Poison.decode!(&1))
    |> Stream.map(&to_structure(&1))
    |> Enum.reduce(%{}, &merge_term_positions(&1, &2))
  end

  # input: %{"3" => [%{"field" => "title", "position" => 0}]}
  # output: %{"3" => MapSet<%Location{:field => :title, :position => 0}>}
  def to_structure(raw) do
    k = hd(Map.keys(raw))
    v = Map.get(raw, k)
    Map.put(%{}, k, to_locations(v))
  end

  # input: %{"field" => "title", "position" => 0}
  # output: MapSet<%Location{:field => :title, :position => 0}>
  def to_locations(raw) do
    raw
    |> Enum.map(fn locs ->
      %{}
      |> Map.put(:field, String.to_atom(Map.get(locs, "field")))
      |> Map.put(:position, Map.get(locs, "position"))
    end)
    |> Enum.map(&struct(Location, &1))
    |> Enum.into(MapSet.new())
  end

  def merge_term_positions(tp1, tp2) do
    Map.merge(tp1, tp2, fn _k, p1, p2 ->
      p1
      |> Enum.concat(p2)
      |> Enum.into(MapSet.new())
    end)
  end

  @doc """
  Index a document in redis
  """
  def _index(doc, index) do
    id = Storable.id(doc)

    term_map =
      id
      |> Index.field_locations(doc)
      |> Enum.reduce(&Index.merge_term_locations(&1, &2))

    result = index_raw(index, term_map, id)
    # TODO: Verify that :error is actually returned from redis
    if List.keymember?(result, :error, 0), do: :error, else: :ok
  end

  defp index_raw(index, term_map, docid) do
    queries =
      term_map
      |> Map.keys()
      |> Stream.map(fn t ->
        {t,
         merge_term_positions(
           Map.get(term_map, t),
           _term_positions(t, index)
         )}
      end)
      |> Stream.flat_map(fn {t, locs} ->
        tl = for {id, loc} <- locs, do: ["SADD", "#{index}_#{t}", Poison.encode!(Map.put(%{}, id, loc))]
        Enum.concat(tl, [["SADD", "#{index}.terms", t]])
      end)
      |> Stream.concat([["SADD", "#{index}.document_ids", docid]])
      |> Stream.concat([["SADD", ".indices", index]])
      |> Enum.to_list()

    Exredis.query_pipe(redis(), queries)
  end

  # TODO: Will need this for deleting all terms of
  # an already existing document (fetch it from store, get all terms) when
  # you would like to overwrite...
  def delete_old_terms(terms, docid, index) do
    client = redis()

    queries =
      terms
      |> Stream.map(fn t -> {t, Exredis.query(client, ["SMEMBERS", "#{index}_#{t}"])} end)
      |> Stream.reject(fn {_t, locs} -> locs == [] end)
      |> Stream.map(fn {t, locs} -> {t, Poison.decode!(locs)} end)
      |> Stream.filter(fn {_t, m} -> hd(Map.keys(m)) == docid end)
      |> Stream.map(fn {t, m} -> ["SREM", "#{index}_#{t}", Poison.encode!(m)] end)

    Exredis.query_pipe(client, Enum.to_list(queries))
  end

  @doc """
  Deletes the doc (its terms and document id)
  """
  def _delete_doc(did, index) do
    Logger.debug("Deleting document #{did} from index #{index}")

    queries =
      index
      |> _terms()
      |> Stream.map(fn t -> {t, _term_positions(t, index)} end)
      |> Stream.filter(fn {_term, pos} -> Map.has_key?(pos, did) end)
      |> Stream.map(fn {t, pos} -> {t, Map.put(%{}, did, Map.get(pos, did))} end)
      |> Stream.map(fn {term, pos} ->
        ["SREM", "#{index}_#{term}", Poison.encode!(pos)]
      end)
      |> Stream.concat([["SREM", "#{index}.document_ids", did]])
      |> Enum.to_list()

    Exredis.query_pipe(redis(), queries)
  end

  @doc """
  Deletes the index
  """
  def _clear(index) do
    queries =
      index
      |> _terms()
      # delete all keys in <index>.terms
      |> Stream.map(fn t -> ["DEL", "#{index}_#{t}"] end)
      # |> Stream.concat([["SREM", ".indices", index]]) # delete index from .indices
      # delete index terms
      |> Stream.concat([["DEL", "#{index}.terms"]])
      # and document ids
      |> Stream.concat([["DEL", "#{index}.document_ids"]])
      |> Enum.to_list()

    Exredis.query_pipe(redis(), queries)
  end
end

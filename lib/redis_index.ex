defmodule RedisIndex do
  @moduledoc """
  Redis as a backend for cedrik indices
  """
  @behaviour Indexer

  use Exredis

  defp redis() do
    Application.get_all_env(:redis)[:connection_string]
      |> start_using_connection_string()
  end

  def id(thing) do
    Store.id(thing)
  end

  def indices() do
    redis()
      |>  query(["SMEMBERS", ".indices"])
  end

  def document_ids(index) do
    redis()
      |> query(["SMEMBERS", index <> ".document_ids"])
      |> Enum.into(HashSet.new)
      # |> Stream.map(fn(id) -> id end)
  end

  def terms(index) do
    redis()
      |> query(["SMEMBERS", index <> ".terms"])
      |> Stream.map(fn(t) -> t end)
  end

  @doc """
  Returns a map of positions for each document where the term exist. Ex:
  %{"docId123" => [pos1, pos2], "docIdN" => [pos1]}
  """
  def term_positions(term, index) do
    redis()
      |> query(["SMEMBERS", index <> "_" <> term])
      |> Stream.map(&Poison.decode!(&1)) # [%{"3" => [%{"field" => "title", "position" => 0}]}]
      |> Stream.map(&to_structure(&1))
      |> Enum.reduce(%{}, &merge_term_positions(&1, &2))
  end

  # input: %{"3" => [%{"field" => "title", "position" => 0}]}
  # output: %{"3" => HashSet<%Location{:field => :title, :position => 0}>}
  def to_structure(raw) do
    k = hd(Map.keys(raw))
    v = Map.get(raw, k)
    Map.put(%{}, k, to_locations(v))
  end

  # input: %{"field" => "title", "position" => 0}
  # output: HashSet<%Location{:field => :title, :position => 0}>
  def to_locations(raw) do
    raw
      |> Enum.map(fn(locs) ->
        Map.put(%{}, :field, Map.get(locs, "field") |> String.to_atom)
          |> Map.put(:position, Map.get(locs, "position"))
      end)
      |> Enum.map(&struct(Location, &1))
      |> Enum.into(HashSet.new)
  end

  def merge_term_positions(tp1, tp2) do
    Map.merge(tp1, tp2,
      fn(_k, p1, p2) ->
        Enum.concat(p1, p2)
          |> Enum.into(HashSet.new)
      end)
  end

  @doc """
  Index a document in redis
  """
  def index(doc, index) do
    id = id(doc)
    term_map = Indexer.field_locations(id, doc)
      |> Enum.reduce(&Indexer.merge_term_locations(&1, &2))
    index_raw(index, term_map, id)
  end

  defp index_raw(index, term_map, docid) do
    client = redis()
    term_map
      |> Map.keys
      |> Stream.map(fn(t) ->
          {t, merge_term_positions(Map.get(term_map, t),
            term_positions(t, index))}
        end)
      |> Stream.each(fn({t, tm}) ->
          client |>
            query_pipe([["SADD", index <> "_" <> t, Poison.encode!(tm)],
              ["SADD", index <> ".terms", t],
              ["SADD", index <> ".document_ids", docid],
              ["SADD", ".indices", index]])
        end)
      |> Stream.run
  end

  @doc """
  Deletes the doc (its terms and document id)
  """
  def delete_doc(did, index) do
    IO.puts("Deleting document #{did} from index #{index}")

    doc_ids = document_ids(index)
      |> Stream.reject(fn(x) -> x == did end)

    mod_terms = terms(index)
      |> Stream.filter(fn({_term, pos}) -> Map.has_key?(pos, did) end)
      |> Stream.map(fn({term, pos}) ->
          {term, Map.drop(pos, [did])}
        end)
      |> Enum.into(%{})

    redis()
      |> query_pipe([["SREM", index <> ".document_ids", did]])
      # TODO: Go through the terms of this document, for each of them
      # SREM from index <> "_" term
  end

  @doc """
  Deletes the index
  """
  def delete(index) do
    queries = terms(index)
      |> Stream.map(fn(t) -> ["DEL", index <> "_" <> t] end) # delete all keys in <index>.terms
      |> Stream.concat([["SREM", ".indices", index]]) # delete index from .indices
      |> Stream.concat([["DEL", index <> ".terms"]]) # delete index term
      |> Stream.concat([["DEL", index <> ".document_ids"]]) # and document ids

    redis()
      |> query_pipe(queries |> Enum.to_list)
  end
end


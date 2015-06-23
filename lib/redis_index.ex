defmodule RedisIndex do
  @moduledoc """
  Redis as a backend for cedrik indices
  """
  
  use Exredis

  defp redis() do
    Application.get_all_env(:redis)[:connection_string]
      |> start_using_connection_string()
  end

  @doc """
  Returns all existing indices
  """
  def indices() do
    redis()
      |>  query(["SMEMBERS", ".indices"])
  end

  @doc """
  Returns the document ids that exist in the index
  """
  def document_ids(index) do
    redis()
      |> query(["SMEMBERS", index <> ".document_ids"])
      # |> Stream.map(fn(id) -> id end)
  end

  @doc """
  Returns a stream of terms that exist in the index
  """
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
      |> Stream.map(&Poison.decode!(&1))
      |> Enum.reduce(%{}, &merge_term_positions(&1, &2))
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
  def index(id, doc, index) do
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
  def delete_doc(doc, index) do
  end

  @doc """
  Deletes the index
  """
  def delete(index) do
    # 1. delete all keys in <index>.terms
    # 2. delete index.terms
    # 3. delete index.document_ids
    # 4. delete index from .indices
  end
end


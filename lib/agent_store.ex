defmodule AgentStore do
  @moduledoc """
  In-memory document storage
  """

  defimpl Store, for: [Map, Document] do
    def store(doc) do
      #Indexer.index(id(map), map, index)
      AgentStore.put(id(doc), doc)
    end

    # TODO: Use some actual UUID here instead of random
    def id(doc) do
      Map.get(doc, :id,
        Map.get(doc, "id", :random.uniform * 1000000))
      |> to_string
    end

    def delete(doc) do
      AgentStore.delete([id(doc)])
    end
  end

  @doc """
  Starts a new AgentStore.
  """
  def start_link do
    Agent.start_link(fn -> Map.new end, name: __MODULE__)
  end

  @doc """
  Gets a value by `key`.
  """
  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  @doc """
  Puts the `value` for the given `key`
  """
  def put(key, doc) do
    Agent.update(__MODULE__, &Map.put(&1, key, doc))
  end


  @doc """
  Deletes the documents with id in keys
  """
  def delete(keys) do
    Agent.update(__MODULE__, &Map.drop(&1, keys))
  end
end


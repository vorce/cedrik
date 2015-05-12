defmodule Indexstore do
  @doc """
  Starts a new Indexstore.
  """
  def start_link do
    Agent.start_link(fn -> Map.new end, name: __MODULE__)
  end

  @doc """
  Gets a value by `key`. If it doesn't exist
  creates a new index.
  """
  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key, %Index{name: key}))
  end

  @doc """
  Puts the `value` for the given `key`
  """
  def put(index) do
    Agent.update(__MODULE__, &Map.put(&1, index.name, index))
  end
end


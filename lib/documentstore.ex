defmodule Documentstore do
  @doc """
  Starts a new Documentstore.
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
end


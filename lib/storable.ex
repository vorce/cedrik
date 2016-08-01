defprotocol Storable do
  @doc "Store an elixir data structure in Cedrik"
  def store(thing)

  @doc "Identify an elixir data structure uniquely, must return a string"
  def id(thing)

  @doc "Delete something that was already stored"
  def delete(thing)
end

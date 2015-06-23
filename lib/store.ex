defprotocol Store do
  @doc "Store an elixir data structure in Cedrik"
  def store(thing, index)

  @doc "Identify an elixir data structure, must return a string"
  def id(thing)

  @doc "Delete something that was already stored"
  def delete(thing, index)
end

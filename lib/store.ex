defprotocol Store do
  @doc "Store in Cedrik"
  def store(thing, index)
  def id(thing)
end
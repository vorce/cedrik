defprotocol Search do
  @doc "Search in Cedrik"
  def search(query, indices)
end

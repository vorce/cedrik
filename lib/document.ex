defmodule Document do
  @moduledoc """
  An example data structure to index
  """

  defstruct id: 0, title: "", body: "", publish_date: {1970, 1, 1}, index_date: {}
  @type t :: %Document{id: integer, title: String.t, body: String.t, publish_date: Tuple.t, index_date: Tuple.t}
end

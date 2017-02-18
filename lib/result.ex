defmodule Result do
  @moduledoc """
  Represent a search result
  """

  defstruct hits: []
  @type t :: %Result{hits: List.t}
end

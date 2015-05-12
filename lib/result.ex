defmodule Result do
  @derive [Access]
  defstruct hits: []
  @type t :: %Result{hits: List.t}
end

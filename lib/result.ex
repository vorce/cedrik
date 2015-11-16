defmodule Result do
  defstruct hits: []
  @type t :: %Result{hits: List.t}
end

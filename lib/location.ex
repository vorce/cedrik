defmodule Location do
  defstruct field: nil, position: 0
  @type t :: %Location{field: Atom.t, position: integer}
end

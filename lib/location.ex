defmodule Location do
  @derive [Access]
  defstruct field: nil, position: 0
  @type t :: %Location{field: Atom.t, position: integer}
end

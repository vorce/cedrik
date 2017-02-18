defmodule Location do
  @moduledoc """
  Describes where a match was found in a document
  """

  defstruct field: nil, position: 0
  @type t :: %Location{field: Atom.t, position: integer}
end

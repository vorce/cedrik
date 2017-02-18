defmodule Cedrik do
  @moduledoc """
  Cedrik OTP Application definition
  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(IndexSupervisor, [])
    ]

    opts = [strategy: :one_for_one, name: Cedrik.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

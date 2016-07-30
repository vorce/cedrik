defmodule IndexSupervisor do
  @moduledoc """
  Supervises all indices in Cedrik. Also handles listing and removing indices.
  TODO: Clean up responsibilities between Index and IndexSupervisor modules.
  """

  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    index_workers = Application.get_env(:cedrik, IndexSupervisor)
      |> Keyword.get(:indices)

    workers = index_workers
      |> Enum.map(fn({k, v}) -> worker(v, [[name: k]], id: k) end)

    opts = [strategy: :one_for_one, name: __MODULE__]
    supervise(workers, opts)
  end

  @doc "Lists all existing indices in Cedrik. Returns a list of tuples that look like: {pid, name, module}"
  def list() do
    Supervisor.which_children(__MODULE__)
    |> Enum.filter(fn({_id, _child, type, _modules}) -> type == :worker end)
    |> Enum.map(fn({_id, pid, _type, modules}) -> {pid, hd(modules).get(pid).name, hd(modules)} end)
  end

  @doc "Lists all indices matching the list of given index names. Returns a list of tuples on the same format as Index.list/0"
  def list(indices) when is_list(indices) do
    Supervisor.which_children(__MODULE__)
    |> Enum.filter(fn({_id, _child, type, _modules}) -> type == :worker end)
    |> Enum.map(fn({_id, pid, _type, modules}) -> {modules, pid} end)
    |> Enum.map(fn({modules, pid}) -> {pid, hd(modules).get(pid).name, hd(modules)} end)
    |> Enum.filter(fn({_pid, name, _module}) -> Enum.member?(indices, name) end)
  end

  @doc "Gives back details about the given index_name if it exsits: {pid, name, module}"
  def by_name(index_name) do
     matches = Supervisor.which_children(__MODULE__)
     |> Enum.filter(fn({_id, _child, type, _modules}) -> type == :worker end)
     |> Enum.map(fn({_id, pid, _type, modules}) -> {modules, pid} end)
     |> Enum.filter(fn({modules, pid}) -> hd(modules).get(pid).name == index_name end)
     |> Enum.map(fn({modules, pid}) -> {pid, index_name, hd(modules)} end)

     cond do
        matches == [] -> {:error, :not_found}
        true -> hd(matches)
     end
  end

  @doc "Remove an index from Cedrik"
  def remove({pid, name, module}) do
     module.clear(pid)
     Supervisor.terminate_child(__MODULE__, name)
     Supervisor.delete_child(__MODULE__, name)
  end
end

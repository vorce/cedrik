defmodule IndexSupervisor do
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

  def index_pids() do
    Supervisor.which_children(__MODULE__)
    |> Enum.filter(fn({_id, _child, type, _modules}) -> type == :worker end)
    |> Enum.map(fn({_id, pid, _type, modules}) -> {pid, hd(modules)} end)
  end

  def index_pids(indices) when is_list(indices) do
    Supervisor.which_children(__MODULE__)
    |> Enum.filter(fn({_id, _child, type, _modules}) -> type == :worker end)
    |> Enum.map(fn({_id, pid, _type, modules}) -> {modules, pid} end)
    |> Enum.filter(fn({modules, pid}) -> Enum.member?(indices, hd(modules).get(pid).name) end)
    |> Enum.map(fn({modules, pid}) -> {pid, hd(modules)} end)
  end

  def pid_by_name(index_name) do
     matches = Supervisor.which_children(__MODULE__)
     |> Enum.filter(fn({_id, _child, type, _modules}) -> type == :worker end)
     |> Enum.map(fn({_id, pid, _type, modules}) -> {modules, pid} end)
     |> Enum.filter(fn({modules, pid}) -> hd(modules).get(pid).name == index_name end)
     |> Enum.map(fn({modules, pid}) -> {pid, hd(modules)} end)

     cond do
        matches == [] -> {:error, "No such index: #{index_name}"}
        true -> hd(matches)
     end
  end
end

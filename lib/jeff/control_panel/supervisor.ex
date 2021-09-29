defmodule Jeff.ControlPanel.Supervisor do
  @moduledoc false

  use DynamicSupervisor

  alias Jeff.ControlPanel

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_child(name, opts) do
    spec = ControlPanel.child_spec(name, opts)
    {:ok, _pid} = DynamicSupervisor.start_child(__MODULE__, spec)

    :ok
  end

  def which_children() do
    Supervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.map(&ControlPanel.Registry.name/1)
  end

  def terminate_child(name) do
    pid = ControlPanel.Registry.pid(name)
    :ok = DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

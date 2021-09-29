defmodule Jeff.ControlPanel.Registry do
  @moduledoc false

  def via(name) do
    {:via, Registry, {__MODULE__, name}}
  end

  def name(pid) do
    Registry.keys(__MODULE__, pid)
    |> List.first()
  end

  def pid(name) do
    case Registry.lookup(__MODULE__, name) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end
end

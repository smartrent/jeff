defmodule Jeff do
  alias Jeff.ControlPanel

  import ControlPanel.Registry, only: [via: 1]

  def start_control_panel(name, opts \\ []) do
    :ok = ControlPanel.Supervisor.start_child(name, opts)
  end

  def stop_control_panel(name) do
    :ok = ControlPanel.Supervisor.terminate_child(name)
  end

  def get_control_panels() do
    ControlPanel.Supervisor.which_children()
  end

  def connect_device(name, address, opts) do
    :ok = ControlPanel.add_device(via(name), address, opts)
  end

  def subscribe(name) do
    :ok = ControlPanel.PubSub.subscribe(name)
  end
end

defmodule Jeff.Application do
  @moduledoc false

  use Application

  alias Jeff.ControlPanel

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: ControlPanel.Registry},
      ControlPanel.PubSub,
      ControlPanel.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Jeff.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

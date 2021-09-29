defmodule Jeff.ControlPanel.PubSub do
  @moduledoc false

  @registry __MODULE__

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link() do
    Registry.start_link(name: @registry, keys: :duplicate)
  end

  def subscribe(name) do
    {:ok, _} = Registry.register(@registry, name, [])
    :ok
  end

  def publish(name, message) do
    Registry.dispatch(@registry, name, fn entries ->
      for {pid, _} <- entries, do: send(pid, message)
    end)
  end
end

defmodule Jeff.Bus do
  @moduledoc false

  alias Jeff.Device

  defstruct registry: %{},
            command: nil,
            reply: nil,
            cursor: nil,
            poll: [],
            conn: nil,
            controlling_process: nil

  def new(_opts \\ []) do
    %__MODULE__{}
  end

  def add_device(bus, opts \\ []) do
    device = Device.new(opts)
    _bus = register(bus, device.address, device)
  end

  def get_device(%{registry: registry}, address) do
    Map.fetch!(registry, address)
  end

  def registered?(%{registry: registry}, address) do
    is_map_key(registry, address)
  end

  def put_device(%{cursor: cursor} = bus, device) do
    register(bus, cursor, device)
  end

  def put_device(bus, address, device) do
    register(bus, address, device)
  end

  def current_device(%{cursor: cursor} = bus) do
    get_device(bus, cursor)
  end

  defp register(%{registry: registry} = bus, address, device) do
    registry = Map.put(registry, address, device)
    %{bus | registry: registry}
  end

  defp register(%{cursor: cursor} = bus, device) do
    _bus = register(bus, cursor, device)
  end

  def tick(%{cursor: nil, poll: []} = bus) do
    poll = addresses(bus)
    %{bus | poll: poll}
  end

  def tick(%{cursor: nil, poll: poll} = bus) do
    [cursor | poll] = poll
    %{bus | cursor: cursor, poll: poll}
  end

  def tick(%{command: nil} = bus) do
    {device, command} = current_device(bus) |> Device.next_command()
    bus = register(bus, device)
    %{bus | command: command}
  end

  # wait for reply
  def tick(%{reply: nil} = bus) do
    bus
  end

  # handle reply and reset
  def tick(%{reply: _reply} = bus) do
    bus = maybe_validate_reply(bus)

    # TODO: Convert sleep to part of functional core
    if bus.poll == [], do: Process.sleep(100)

    %{bus | command: nil, cursor: nil, reply: nil}
  end

  defp maybe_validate_reply(%{reply: :timeout} = bus), do: bus

  defp maybe_validate_reply(bus) do
    device = current_device(bus) |> Device.receive_valid_reply()
    register(bus, device)
  end

  def send_command(bus, %{address: address} = command) do
    device = get_device(bus, address) |> Device.send_command(command)
    _bus = register(bus, address, device)
  end

  def receive_reply(bus, reply) do
    %{bus | reply: reply}
  end

  defp addresses(bus) do
    Map.keys(bus.registry)
  end
end

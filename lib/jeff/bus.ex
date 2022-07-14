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

  @type t :: %__MODULE__{}

  @spec new(keyword()) :: t()
  def new(_opts \\ []) do
    %__MODULE__{}
  end

  @spec add_device(t(), keyword()) :: t()
  def add_device(bus, opts \\ []) do
    device = Device.new(opts)
    _bus = register(bus, device.address, device)
  end

  @spec remove_device(t(), byte()) :: t()
  def remove_device(%{poll: poll, registry: registry} = bus, address) do
    registry = Map.delete(registry, address)
    poll = Enum.reject(poll, &(&1 == address))
    %{bus | poll: poll, registry: registry}
  end

  @spec get_device(t(), byte()) :: Device.t()
  def get_device(%{registry: registry}, address) do
    Map.fetch!(registry, address)
  end

  @spec registered?(t(), byte()) :: boolean()
  def registered?(%{registry: registry}, address) do
    is_map_key(registry, address)
  end

  @spec put_device(t(), Device.t()) :: t()
  def put_device(%{cursor: cursor} = bus, device) do
    register(bus, cursor, device)
  end

  @spec put_device(t(), byte(), Device.t()) :: t()
  def put_device(bus, address, device) do
    register(bus, address, device)
  end

  @spec current_device(%__MODULE__{cursor: byte(), registry: map()}) :: Device.t()
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

  @spec tick(t()) :: t()
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

  @spec send_command(t(), Jeff.Command.t()) :: t()
  def send_command(bus, %{address: address} = command) do
    device = get_device(bus, address) |> Device.send_command(command)
    register(bus, address, device)
  end

  @spec receive_reply(t(), Jeff.Reply.t()) :: t()
  def receive_reply(bus, reply) do
    %{bus | reply: reply}
  end

  defp addresses(bus) do
    Map.keys(bus.registry)
  end
end

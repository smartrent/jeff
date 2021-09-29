defmodule Jeff.ControlPanel do
  require Logger

  use GenServer
  alias Jeff.{Bus, Command, Message, Reply, SecureChannel, Transport}

  def start_link(name, opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__.Registry.via(name))
  end

  def child_spec(name, opts) do
    %{
      id: name,
      start: {__MODULE__, :start_link, [name, opts]},
      restart: :transient
    }
  end

  def add_device(pid, address, opts \\ []) do
    opts = Keyword.merge(opts, address: address)
    GenServer.call(pid, {:add_device, opts})
  end

  def send_command(pid, address, name, params \\ []) do
    GenServer.call(pid, {:send_command, address, name, params})
  end

  def id_report(pid, address) do
    send_command(pid, address, ID)
  end

  def capabilities(pid, address) do
    send_command(pid, address, CAP)
  end

  def local_status(pid, address) do
    send_command(pid, address, LSTAT)
  end

  def input_status(pid, address) do
    send_command(pid, address, ISTAT)
  end

  def set_led(pid, address, params) do
    send_command(pid, address, LED, params)
  end

  def set_buzzer(pid, address, params) do
    send_command(pid, address, BUZ, params)
  end

  def set_com(pid, address, params) do
    send_command(pid, address, COMSET, params)
  end

  def set_key(pid, address, params) do
    send_command(pid, address, KEYSET, params)
  end

  def abort(pid, address) do
    send_command(pid, address, ABORT)
  end

  @impl GenServer
  def init(opts) do
    serial_port = Keyword.get(opts, :serial_port, "/dev/ttyUSB0")
    {:ok, conn} = Transport.start_link({serial_port, self(), opts})

    state = Bus.new()
    state = %{state | conn: conn}

    {:ok, tick(state)}
  end

  @impl GenServer
  def handle_call({:send_command, address, name, params}, from, state) do
    params = Keyword.put(params, :caller, from)
    command = Command.new(address, name, params)
    state = Bus.send_command(state, command)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:add_device, opts}, _from, state) do
    state = Bus.add_device(state, opts)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info(:tick, %{command: nil, reply: nil} = state) do
    {:noreply, tick(state)}
  end

  def handle_info(:tick, %{command: command, reply: nil} = state) do
    device = Bus.current_device(state)

    command_message = Message.new(device, command)
    device = command_message.device

    {:ok, reply_message} = Transport.send_message(state.conn, command_message)

    # save the device with the possibly updated secure channel
    state = Bus.put_device(state, device)

    state =
      if device.secure_channel.established? do
        len = reply_message.length - Message.check_size(reply_message) - 4
        <<bytes::binary-size(len), _rest::binary>> = reply_message.bytes
        secure_channel = SecureChannel.calculate_mac(device.secure_channel, bytes, false)
        Bus.put_device(state, %{device | secure_channel: secure_channel})
      else
        state
      end

    reply_message =
      if reply_message.sb_type == 0x18 do
        data = SecureChannel.decrypt(device.secure_channel, reply_message.data)
        %{reply_message | data: data}
      else
        reply_message
      end

    reply = Reply.new(reply_message)

    if reply.name == KEYPAD do
      name = __MODULE__.Registry.name(self())
      message = {:keypress, name, reply.address, reply.data}
      __MODULE__.PubSub.publish(name, message)
    end

    if reply.name == RAW do
      name = __MODULE__.Registry.name(self())
      message = {:raw, name, reply.address, reply.data}
      __MODULE__.PubSub.publish(name, message)
    end

    state = handle_reply(state, reply)

    if command.caller do
      GenServer.reply(command.caller, reply)
    end

    state = %{state | reply: reply}
    {:noreply, tick(state)}
  end

  # handle transport connected
  def handle_info(:connected, state) do
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  # Helper functions

  defp handle_reply(state, %{name: CCRYPT} = reply) do
    device = Bus.current_device(state)
    secure_channel = SecureChannel.initialize(device.secure_channel, reply.data)
    device = %{device | secure_channel: secure_channel}
    Bus.put_device(state, device)
  end

  defp handle_reply(state, %{name: RMAC_I} = reply) do
    device = Bus.current_device(state)
    secure_channel = SecureChannel.establish(device.secure_channel, reply.data)
    device = %{device | secure_channel: secure_channel}
    Bus.put_device(state, device)
  end

  defp handle_reply(state, _reply), do: state

  defp tick(bus) do
    send(self(), :tick)
    Bus.tick(bus)
  end
end

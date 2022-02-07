defmodule Jeff.ControlPanel do
  require Logger

  use GenServer
  alias Jeff.{Bus, Command, Device, Events, Message, Reply, SecureChannel, Transport}

  @max_reply_delay 200

  @type osdp_address :: 0x0..0x7F
  @type address_availability :: :available | :registered | :timeout | :error

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def add_device(pid, address, opts \\ []) do
    opts = Keyword.merge(opts, address: address)
    GenServer.call(pid, {:add_device, opts})
  end

  def send_command(pid, address, name, params \\ []) do
    GenServer.call(pid, {:send_command, address, name, params})
  end

  def send_command_oob(pid, address, name, params \\ []) do
    GenServer.call(pid, {:send_command_oob, address, name, params})
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

  @doc """
  Determine if a device is available to be registered on the bus.
  """
  @spec check_address(GenServer.server(), osdp_address()) :: address_availability()
  def check_address(pid, address) do
    GenServer.call(pid, {:check_address, address})
  end

  @impl GenServer
  def init(opts) do
    controlling_process = Keyword.get(opts, :controlling_process)
    serial_port = Keyword.get(opts, :serial_port, "/dev/ttyUSB0")
    {:ok, conn} = Transport.start_link(port: serial_port, speed: 9600)

    state = Bus.new()
    state = %{state | conn: conn, controlling_process: controlling_process}

    {:ok, tick(state)}
  end

  @impl GenServer
  def handle_call({:send_command, address, name, params}, from, state) do
    params = Keyword.put(params, :caller, from)
    command = Command.new(address, name, params)
    state = Bus.send_command(state, command)
    {:noreply, state}
  end

  def handle_call({:send_command_oob, address, name, params}, _from, state) do
    device = Device.new(address: address)
    command = Command.new(address, name, params)
    %{bytes: bytes} = Message.new(device, command)

    resp =
      case send_data_oob(state, address, bytes) do
        {:error, _reason} = error -> error
        {:ok, bytes} -> Message.decode(bytes) |> Reply.new()
      end

    {:reply, resp, state}
  end

  @impl GenServer
  def handle_call({:check_address, address}, _from, state) do
    device = Device.new(address: address)
    command = Command.new(address, POLL)
    %{bytes: bytes} = Message.new(device, command)

    status =
      case send_data_oob(state, address, bytes) do
        {:error, :registered} ->
          :registered

        {:error, :timeout} ->
          :timeout

        {:ok, bytes} ->
          try do
            Message.decode(bytes)
            :available
          rescue
            _error -> :error
          end
      end

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call({:add_device, opts}, _from, state) do
    address = Keyword.fetch!(opts, :address)
    state = Bus.add_device(state, opts)
    device = Bus.get_device(state, address)
    {:reply, device, state}
  end

  @impl GenServer
  def handle_info(:tick, %{command: nil, reply: nil} = state) do
    {:noreply, tick(state)}
  end

  def handle_info(:tick, %{command: command, reply: nil, conn: conn} = state) do
    device = Bus.current_device(state)
    %{device: device, bytes: bytes} = Message.new(device, command)

    # save the device with the possibly updated secure channel
    state = Bus.put_device(state, device)

    :ok = Transport.send(conn, bytes)
    state = Transport.recv(conn, @max_reply_delay) |> handle_recv(state)

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

  defp handle_recv(
         {:ok, bytes},
         %{controlling_process: controlling_process, command: command} = state
       ) do
    reply_message = Message.decode(bytes)

    device = Bus.current_device(state)

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

    if controlling_process do
      if reply.name == KEYPAD do
        event = Events.Keypress.from_reply(reply)
        send(controlling_process, event)
      end

      if reply.name == RAW do
        event = Events.CardRead.from_reply(reply)
        send(controlling_process, event)
      end
    end

    state = handle_reply(state, reply)

    if command.caller do
      GenServer.reply(command.caller, reply)
    end

    %{state | reply: reply}
  end

  defp handle_recv({:error, :timeout}, state) do
    %{state | reply: :timeout}
  end

  defp send_data_oob(state, address, bytes) do
    if Bus.registered?(state, address) do
      {:error, :registered}
    else
      :ok = Transport.send(state.conn, bytes)
      Transport.recv(state.conn, @max_reply_delay)
    end
  end

  defp tick(bus) do
    send(self(), :tick)
    Bus.tick(bus)
  end
end

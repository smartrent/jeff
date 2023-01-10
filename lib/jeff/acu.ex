defmodule Jeff.ACU do
  @moduledoc """
  GenServer process for an ACU.

  ### Messages

  If `Jeff.ACU` is started with the `controlling_process` option, the passed pid
  will be sent any unsolicited events/replies received from peripheral devices, as
  well as messages regarding device status.

  Unsolicited events/replies consist of any of the following structs:

  * `Jeff.Events.CardRead`
  * `Jeff.Events.Keypress`
  * `Jeff.Reply`

  Device status messages will be sent as tuples:

  * `{:install_mode_complete, %Jeff.Device{}}` - sent when a device has had its
    SCBK set and the secure channel will be re-established with the new SCBK
  * `{:secure_channel_failed, %Jeff.Device{}}` - sent when a device is removed from
    the `Jeff.ACU` due to secure channel establishment failure
  """

  require Logger

  use GenServer
  alias Jeff.{Bus, Command, Device, Events, Message, Reply, SecureChannel, Transport}

  @max_reply_delay 200

  @type acu() :: Jeff.acu()
  @type address_availability :: :available | :registered | :timeout | :error
  @type osdp_address() :: Jeff.osdp_address()

  @type start_opt() ::
          {:name, atom()}
          | {:serial_port, String.t()}
          | {:controlling_process, Process.dest()}
          | {:transport_opts, Transport.opts()}

  @doc """
  Start the ACU process.
  """
  @spec start_link([start_opt()]) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Register a peripheral device on the ACU communication bus.
  """
  @spec add_device(acu(), osdp_address(), [Device.opt()]) :: Device.t()
  def add_device(acu, address, opts \\ []) do
    GenServer.call(acu, {:add_device, address, opts})
  end

  @spec get_device(acu(), osdp_address()) :: Device.t()
  def get_device(acu, address) do
    GenServer.call(acu, {:get_device, address})
  end

  @doc """
  Remove a peripheral device from the ACU communication bus.
  """
  @spec remove_device(acu(), osdp_address()) :: Device.t()
  def remove_device(acu, address) do
    GenServer.call(acu, {:remove_device, address})
  end

  @doc """
  Send a command to a peripheral device.
  """
  @spec send_command(acu(), osdp_address(), atom(), keyword()) :: Reply.t()
  def send_command(acu, address, name, params \\ []) do
    GenServer.call(acu, {:send_command, address, name, params})
  end

  @doc """
  Send a command to a peripheral device that is not yet registered on the ACU.
  Intended to be used for maintenance/diagnostic purposes.
  """
  @spec send_command_oob(acu(), osdp_address(), atom(), keyword()) :: Reply.t()
  def send_command_oob(acu, address, name, params \\ []) do
    GenServer.call(acu, {:send_command_oob, address, name, params})
  end

  @doc """
  Determine if a device is available to be registered on the bus.
  """
  @spec check_address(acu(), osdp_address()) :: address_availability()
  def check_address(acu, address) do
    GenServer.call(acu, {:check_address, address})
  end

  @impl GenServer
  def init(opts) do
    controlling_process = Keyword.get(opts, :controlling_process)
    serial_port = Keyword.get(opts, :serial_port, "/dev/ttyUSB0")
    transport_opts = Keyword.get(opts, :transport_opts, [])
    {:ok, conn} = Transport.start_link(serial_port, transport_opts)

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
            _ = Message.decode(bytes)
            :available
          rescue
            _error -> :error
          end
      end

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call({:add_device, address, opts}, _from, state) do
    opts = Keyword.merge(opts, address: address)
    state = Bus.add_device(state, opts)
    device = Bus.get_device(state, address)
    {:reply, device, state}
  end

  def handle_call({:get_device, address}, _from, state) do
    device = Bus.get_device(state, address)
    {:reply, device, state}
  end

  def handle_call({:remove_device, address}, _from, state) do
    device = Bus.get_device(state, address)
    state = Bus.remove_device(state, address)
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

  @impl GenServer
  def terminate(_reason, state) do
    Transport.close(state.conn)
  end

  # Helper functions

  defp handle_reply(state, %{name: CCRYPT} = reply) do
    device = Bus.current_device(state)

    device =
      case SecureChannel.initialize(device.secure_channel, reply.data) do
        {:ok, sc} ->
          %{device | secure_channel: sc}

        :error ->
          if device.install_mode? do
            # TODO:
            maybe_notify(state, {:secure_channel_failed, device})
            device
          else
            Device.install_mode(device)
          end
      end

    Bus.put_device(state, device)
  end

  defp handle_reply(state, %{name: RMAC_I} = reply) do
    device = Bus.current_device(state)
    secure_channel = SecureChannel.establish(device.secure_channel, reply.data)
    device = %{device | secure_channel: secure_channel}

    Bus.put_device(state, device)
  end

  defp handle_reply(%{command: %{name: KEYSET}} = state, %{name: ACK}) do
    device = Bus.current_device(state)
    secure_channel = SecureChannel.new(scbk: device.scbk)

    if device.install_mode? do
      maybe_notify(state, {:install_mode_complete, device})
    end

    device = %{device | install_mode?: false, secure_channel: secure_channel}

    Bus.put_device(state, device)
  end

  # NAK - unexpected sequence number
  defp handle_reply(state, %{name: NAK, data: %Reply.ErrorCode{code: 0x04}}) do
    device = Bus.current_device(state)
    device = Device.reset(device)
    Bus.put_device(state, device)
  end

  # NAK while establishing secure channel
  defp handle_reply(
         %{command: %{name: command_name}} = state,
         %{name: NAK, data: %Reply.ErrorCode{code: code}} = _reply
       )
       when command_name in [CHLNG, SCRYPT] and code in [0x06, 0x09] do
    device = Bus.current_device(state)

    if device.install_mode? do
      maybe_notify(state, {:secure_channel_failed, device})
    else
      state
    end
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

    # Handle solicited and unsolicited replies
    cond do
      command.caller ->
        GenServer.reply(command.caller, reply)

      is_nil(controlling_process) ->
        :ok

      reply.name in [ACK, NAK, CCRYPT, RMAC_I] ->
        :ok

      reply.name == KEYPAD ->
        event = Events.Keypress.from_reply(reply)
        maybe_notify(state, event)

      reply.name == RAW ->
        event = Events.CardRead.from_reply(reply)
        maybe_notify(state, event)

      true ->
        maybe_notify(state, reply)
    end

    state = handle_reply(state, reply)

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

  defp maybe_notify(%{controlling_process: pid}, message) when is_pid(pid), do: send(pid, message)
  defp maybe_notify(_, message), do: message
end

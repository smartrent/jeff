defmodule Jeff.Transport do
  require Logger
  use Connection
  alias Circuits.UART

  alias Jeff.Message

  @defaults [
    speed: 9600,
    active: true,
    timeout: 5000,
    framing: Jeff.Framing,
    rx_framing_timeout: 200
  ]

  def start_link({device, owner, opts}) do
    Connection.start_link(__MODULE__, {device, owner, opts})
  end

  def send_message(conn, message) do
    case Connection.call(conn, {:send_message, message}) do
      :ok -> :ok
      {:ok, msg} -> {:ok, msg}
      {:error, error} -> {:error, error}
    end
  end

  def set_speed(conn, speed) do
    Connection.call(conn, {:set_speed, speed})
  end

  def open(conn) do
    Connection.call(conn, :open)
  end

  def close(conn) do
    Connection.call(conn, :close)
  end

  def reopen(conn) do
    _ = close(conn)
    Process.sleep(200)
    open(conn)
  end

  # Connection API

  def init({device, owner, opts}) do
    opts = Keyword.merge(@defaults, opts)
    {:ok, uart} = UART.start_link()

    s = %{
      device: device,
      opts: opts,
      uart: uart,
      owner: owner,
      connection: :disconnected,
      callback: nil
    }

    {:connect, :init, s}
  end

  def connect(info, %{uart: uart, device: device, opts: opts} = s) do
    Logger.info("Connecting to channel at #{device}")

    case info do
      {_, from} -> Connection.reply(from, :ok)
      _ -> :noop
    end

    case UART.open(uart, device, opts) do
      :ok ->
        send(s.owner, :connected)
        {:ok, %{s | connection: :connected}}

      {:error, _} ->
        {:backoff, 1000, s}
    end
  end

  def disconnect(info, %{uart: pid, device: device} = s) do
    Logger.info("Disconnecting from channel at #{device}")
    _ = UART.drain(pid)
    :ok = UART.close(pid)

    s = %{s | connection: :disconnected}

    send(s.owner, :disconnected)

    case info do
      {:close, from} ->
        Connection.reply(from, :ok)
        {:noconnect, s}

      {:error, :closed} ->
        Logger.error("Channel connection closed")
        {:connect, :reconnect, s}

      {:error, reason} ->
        Logger.error("Channel connection error: #{inspect(reason)}")
        {:connect, :reconnect, s}
    end
  end

  def handle_call(_, _, %{uart: nil} = s) do
    {:reply, {:error, :closed}, s}
  end

  def handle_call({:set_speed, speed}, _, %{uart: pid, opts: opts} = s) do
    :ok = UART.configure(pid, speed: speed)
    new_state = %{s | opts: Keyword.put(opts, :speed, speed)}
    {:reply, :ok, new_state}
  end

  def handle_call({:send_message, message}, from, %{uart: pid} = s) do
    case UART.write(pid, <<0xFF>> <> message.bytes) do
      :ok ->
        {:noreply, %{s | callback: from}}

      {:error, _} = error ->
        {:disconnect, error, error, s}
    end
  end

  def handle_call(:open, from, s) do
    {:connect, {:open, from}, s}
  end

  def handle_call(:close, from, s) do
    {:disconnect, {:close, from}, s}
  end

  def handle_info({:circuits_uart, _, data}, %{connection: :connected} = s) do
    case recv(data) do
      {:reply, message} ->
        GenServer.reply(s.callback, {:ok, message})
        {:noreply, s}

      {:disconnect, error} ->
        {:disconnect, error, s}
    end
  end

  def handle_info(_, s) do
    {:noreply, s}
  end

  defp recv(bytes) when is_binary(bytes) do
    {:reply, Message.decode(bytes)}
  end

  defp recv({:error, :timeout} = timeout) do
    {:reply, timeout}
  end

  defp recv({:error, _} = error) do
    {:disconnect, error}
  end
end

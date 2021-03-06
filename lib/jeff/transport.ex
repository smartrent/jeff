defmodule Jeff.Transport do
  @moduledoc false

  use Connection
  alias Circuits.UART
  require Logger

  @type baud() :: 9600 | 19200 | 38400 | 57600 | 115_200 | 230_400

  @type args() :: [
          port: binary(),
          speed: baud()
        ]

  @type t() :: [
          port: binary(),
          speed: baud(),
          uart: pid()
        ]

  defstruct port: nil, speed: nil, uart: nil

  @spec start_link(args()) :: GenServer.on_start()
  def start_link(init_args) do
    Connection.start_link(__MODULE__, init_args)
  end

  @spec send(GenServer.server(), binary()) :: :ok | {:error, term()}
  def send(conn, data), do: Connection.call(conn, {:send, data})

  @spec recv(GenServer.server(), non_neg_integer()) :: {:ok, binary()} | {:error, term()}
  def recv(conn, timeout) do
    Connection.call(conn, {:recv, timeout})
  end

  @spec close(GenServer.server()) :: {:close, GenServer.from()}
  def close(conn), do: Connection.call(conn, :close)

  @impl Connection
  def init(init_args) do
    port = Keyword.fetch!(init_args, :port)
    speed = Keyword.fetch!(init_args, :speed)
    {:ok, uart} = UART.start_link()

    s = %{port: port, speed: speed, uart: uart}

    {:connect, :init, s}
  end

  @impl Connection
  def connect(_, %{port: port, speed: speed, uart: uart} = s) do
    opts = [speed: speed, active: false, framing: Jeff.Framing]

    case UART.open(uart, port, opts) do
      :ok ->
        {:ok, s}

      {:error, reason} when reason in [:enoent, :eagain] ->
        {:stop, describe_connect_error(reason, port, uart), s}

      {:error, reason} ->
        log_connect_error(reason, port, uart)
        {:backoff, 1000, s}
    end
  end

  @impl Connection
  def disconnect(info, %{uart: uart} = s) do
    _ = UART.drain(uart)
    :ok = UART.close(uart)

    s = %{s | uart: nil}

    case info do
      {:close, from} ->
        Connection.reply(from, :ok)
        {:stop, :normal, s}

      {:error, :closed} ->
        Logger.error("Serial connection closed")
        {:connect, :reconnect, %{s | uart: nil}}

      {:error, reason} ->
        Logger.error("Serial connection error: #{inspect(reason)}")
        {:connect, :reconnect, %{s | uart: nil}}
    end
  end

  @impl Connection
  def handle_call(_, _, %{uart: nil} = s) do
    {:reply, {:error, :closed}, s}
  end

  @impl Connection
  def handle_call({:send, data}, _, %{uart: uart} = s) do
    case UART.write(uart, <<0xFF>> <> data) do
      :ok ->
        {:reply, :ok, s}

      {:error, _} = error ->
        {:disconnect, error, error, s}
    end
  end

  def handle_call({:recv, timeout}, _, %{uart: uart} = s) do
    case UART.read(uart, timeout) do
      {:ok, <<>>} ->
        {:reply, {:error, :timeout}, s}

      {:ok, _} = ok ->
        {:reply, ok, s}

      {:error, _} = error ->
        {:disconnect, error, error, s}
    end
  end

  def handle_call(:close, from, s) do
    {:disconnect, {:close, from}, s}
  end

  defp log_connect_error(reason, port, uart) do
    description = describe_connect_error(reason, port, uart)
    Logger.error("Error while opening port \"#{port}\": #{description}")
  end

  defp describe_connect_error(:enoent, _port, _uart), do: "the specified port couldn't be found"

  defp describe_connect_error(:eagain, port, uart),
    do: "the port is already opened by another process: #{eagain_processes(port, uart)}"

  defp describe_connect_error(:eacces, _port, _uart),
    do: "permission was denied when opening the port"

  defp describe_connect_error(reason, _port, _uart), do: inspect(reason)

  defp eagain_processes(port, uart) do
    for(
      {pid, prt} <- Circuits.UART.find_pids(),
      Path.basename(prt) == Path.basename(port),
      pid != uart,
      do: inspect(pid)
    )
    |> Enum.join(", ")
  end
end

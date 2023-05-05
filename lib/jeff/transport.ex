defmodule Jeff.Transport do
  @moduledoc false

  use Connection
  alias Circuits.UART
  require Logger

  @type opts :: [Circuits.UART.uart_option()]

  @type t() :: [
          opts: opts(),
          port: binary(),
          uart: pid()
        ]

  defstruct opts: [], port: nil, uart: nil

  @default_opts [active: false, speed: 9600, framing: Jeff.Framing]

  @spec start_link(binary(), opts()) :: GenServer.on_start()
  def start_link(port, opts \\ []) do
    Connection.start_link(__MODULE__, {port, opts})
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
  def init({port, opts}) do
    {:ok, uart} = UART.start_link()

    tracer_opts =
      Application.get_env(:jeff, :tracer, [])
      |> Keyword.merge(opts[:tracer] || [])

    {:ok, tracer} = Jeff.Tracer.start_link(tracer_opts)
    trace? = tracer_opts[:enabled]

    opts =
      Keyword.merge(@default_opts, opts)
      |> Keyword.put_new(:framing, {Jeff.Framing, trace: trace?, tracer: tracer})

    s = %{port: port, opts: opts, trace?: trace?, tracer: tracer, uart: uart}

    {:connect, :init, s}
  end

  @impl Connection
  def connect(_, %{opts: opts, port: port, uart: uart} = s) do
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
    # Add driving byte
    data = <<0xFF>> <> data
    if s.trace?, do: Jeff.Tracer.log(s.tracer, :tx, data)

    case UART.write(uart, data) do
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

      {:ok, bytes} = ok ->
        if s.trace?, do: Jeff.Tracer.log(s.tracer, :rx, bytes)
        {:reply, ok, s}

      {:error, _} = error ->
        {:disconnect, error, error, s}
    end
  end

  def handle_call(:close, from, s) do
    {:disconnect, {:close, from}, s}
  end

  def handle_call({:set_trace, val, opts}, _from, %{trace?: val} = state) do
    # noop
    :ok = GenServer.call(state.tracer, {:configure, opts})
    {:reply, :ok, state}
  end

  def handle_call({:set_trace, val, opts}, _from, state) do
    # force as boolean
    enabled? = val == true || false
    frame_opts = [trace?: enabled?, tracer: state.tracer]

    framing =
      case state.opts[:framing] do
        nil -> {Jeff.Framing, frame_opts}
        {mod, old} -> {mod, Keyword.merge(old, frame_opts)}
        mod -> {mod, frame_opts}
      end

    case UART.configure(state.uart, framing: framing) do
      :ok ->
        :ok = GenServer.call(state.tracer, {:configure, opts})
        {:reply, :ok, %{state | trace?: enabled?}}

      err ->
        {:reply, err, state}
    end
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

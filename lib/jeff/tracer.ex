defmodule Jeff.Tracer do
  @moduledoc false
  use GenServer

  require Logger

  @som Jeff.Message.start_of_message()
  @poll 0x60
  @ack 0x40

  @defaults [
    ignore_polls: true,
    ignore_partials: false,
    ignore_marks: true,
    # 100 bytes
    partials_limit: 100,
    partials: []
  ]

  @type option ::
          {:enabled, boolean}
          | {:ignore_polls, boolean()}
          | {:ignore_partials, boolean()}
          | {:ignore_marks, boolean()}
          | {:partials_limit, pos_integer()}

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Send bytes to the tracer logger
  """
  @spec log(GenServer.server(), :rx | :tx | :partial, iodata()) :: :ok
  def log(tracer, type, bytes), do: GenServer.cast(tracer, {:log, type, bytes})

  @impl GenServer
  def init(opts) do
    state =
      @defaults
      |> Keyword.merge(Application.get_env(:jeff, :tracer, []))
      |> Keyword.merge(opts)
      |> Map.new()

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:configure, opts}, _from, state) do
    {:reply, :ok, Map.merge(state, Map.new(opts))}
  end

  @impl GenServer
  def handle_cast({:log, :partial, _bytes}, %{ignore_partials: true} = state) do
    {:noreply, state}
  end

  def handle_cast({:log, :partial, bytes}, %{ignore_partials: false, partials: partials} = state) do
    state =
      cond do
        state.ignore_marks and all_marks?(bytes) ->
          state

        length(partials) >= state.partials_limit ->
          maybe_log_partials([bytes | partials])
          %{state | partials: []}

        true ->
          %{state | partials: [bytes | partials]}
      end

    {:noreply, state}
  end

  def handle_cast({:log, type, bytes}, state) do
    maybe_log_partials(state.partials)
    maybe_log(type, bytes, state)
    {:noreply, %{state | partials: []}}
  end

  defp all_marks?(<<>>), do: true
  defp all_marks?([]), do: true
  defp all_marks?([0xFF | rem]), do: all_marks?(rem)
  defp all_marks?([next | rem]), do: all_marks?(next) and all_marks?(rem)
  defp all_marks?(<<0xFF, rem::binary>>), do: all_marks?(rem)
  defp all_marks?(<<_byte, _::binary>>), do: false

  defp maybe_log_partials([]), do: :ok

  defp maybe_log_partials(partials) do
    bin = :binary.list_to_bin(Enum.reverse(partials))
    Logger.debug(["[Jeff <-- RX]", IO.ANSI.yellow(), " partial: ", IO.ANSI.cyan(), inspect(bin)])
  end

  defp maybe_log(_, <<255, @som, _::4-bytes, @poll, _::binary>>, %{ignore_polls: true}), do: :ok
  defp maybe_log(_, <<@som, _::4-bytes, @poll, _::binary>>, %{ignore_polls: true}), do: :ok
  defp maybe_log(_, <<@som, 1::1, _::31, @ack, _::binary>>, %{ignore_polls: true}), do: :ok

  defp maybe_log(type, bytes, _state) do
    dir_type_str =
      case type do
        :tx -> [IO.ANSI.green(), "--> TX", IO.ANSI.cyan()]
        :rx -> [IO.ANSI.white(), "<-- RX", IO.ANSI.cyan()]
      end

    Logger.debug(["[Jeff ", dir_type_str, "] ", inspect(bytes)])
  end
end

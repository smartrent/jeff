defmodule Jeff.Framing do
  @moduledoc """
  Implements framing for OSDP packets.

  Waits for a driver byte, then start of message byte, then the length bytes.
  Continues to accumulate bytes until the message length has been reached.
  """

  require Logger

  @behaviour Circuits.UART.Framing

  @som Jeff.Message.start_of_message()

  defmodule State do
    @moduledoc false
    defstruct buffer: nil, packet_length: nil, packets: [], trace?: false, tracer: nil
  end

  @impl true
  def init(args) do
    {:ok, struct(State, args)}
  end

  @impl true
  def add_framing(data, state) when is_binary(data) do
    {:ok, data, state}
  end

  @impl true
  def remove_framing(data, state) do
    process_data(data, state)
  end

  @impl true
  def frame_timeout(state) do
    {:ok, [], %State{trace?: state.trace?}}
  end

  @impl true
  def flush(:transmit, state), do: %State{trace?: state.trace?}
  def flush(:receive, state), do: %State{trace?: state.trace?}
  def flush(:both, state), do: %State{trace?: state.trace?}

  # start a buffer after a driver byte
  defp process_data(<<driver::binary-1, rest::binary>>, %{buffer: nil} = state) do
    if state.trace?, do: Jeff.Tracer.log(state.tracer, :partial, driver)
    process_data(rest, %{state | buffer: <<>>})
  end

  # start buffering after a som byte
  defp process_data(<<@som, rest::binary>>, %{buffer: <<>>} = state) do
    process_data(rest, %{state | buffer: <<@som>>})
  end

  # ignore bytes until start of message
  defp process_data(<<byte::binary-1, rest::binary>>, %{buffer: <<>>} = state) do
    if state.trace?, do: Jeff.Tracer.log(state.tracer, :partial, byte)
    process_data(rest, state)
  end

  # process length of packet after 4 bytes
  defp process_data(data, %{buffer: buffer, packet_length: nil} = state)
       when byte_size(buffer) >= 4 do
    <<_::size(16), packet_length::size(16)-little, _rest::binary>> = buffer
    state = %{state | packet_length: packet_length}
    process_data(data, state)
  end

  # add packet when enough bytes
  defp process_data(data, %{buffer: buffer, packet_length: packet_length} = state)
       when byte_size(buffer) >= packet_length do
    <<packet::binary-size(packet_length), rest::binary>> = buffer
    state = %State{packets: state.packets ++ [packet], trace?: state.trace?}
    process_data(rest <> data, state)
  end

  # # return when no more data to process
  defp process_data(<<>>, %{buffer: buffer, packets: packets} = state) do
    case buffer do
      nil -> {:ok, packets, %State{trace?: state.trace?}}
      _partial -> {:in_frame, packets, %{state | packets: []}}
    end
  end

  # catch all - buffer remaining data
  defp process_data(data, %{buffer: buffer} = state) do
    process_data(<<>>, %{state | buffer: buffer <> data})
  end
end

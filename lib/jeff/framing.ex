defmodule Jeff.Framing do
  @moduledoc """
  Implements framing for OSDP packets.

  Waits for a driver byte, then start of message byte, then the length bytes.
  Continues to accumulate bytes until the message length has been reached.
  """

  @behaviour Circuits.UART.Framing

  @som Jeff.Message.start_of_message()

  defmodule State do
    @moduledoc false
    defstruct buffer: nil, packet_length: nil, packets: []
  end

  @impl true
  def init(_args) do
    state = %State{}
    {:ok, state}
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
  def frame_timeout(_state) do
    new_state = %State{}
    {:ok, [], new_state}
  end

  @impl true
  def flush(:transmit, _state), do: %State{}
  def flush(:receive, _state), do: %State{}
  def flush(:both, _state), do: %State{}

  # start a buffer after a driver byte
  defp process_data(<<_driver::size(8), rest::binary>>, %{buffer: nil} = state) do
    process_data(rest, %{state | buffer: <<>>})
  end

  # start buffering after a som byte
  defp process_data(<<@som, rest::binary>>, %{buffer: <<>>} = state) do
    process_data(rest, %{state | buffer: <<@som>>})
  end

  # ignore bytes until start of message
  defp process_data(<<_byte, rest::binary>>, %{buffer: <<>>} = state) do
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
    state = %State{packets: state.packets ++ [packet]}
    process_data(rest <> data, state)
  end

  # # return when no more data to process
  defp process_data(<<>>, %{buffer: buffer, packets: packets, packet_length: packet_length}) do
    case buffer do
      nil -> {:ok, packets, %State{}}
      partial -> {:in_frame, packets, %State{buffer: partial, packet_length: packet_length}}
    end
  end

  # catch all - buffer remaining data
  defp process_data(data, %{buffer: buffer} = state) do
    process_data(<<>>, %{state | buffer: buffer <> data})
  end
end

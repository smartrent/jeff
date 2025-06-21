defmodule Jeff.Command.FileTransfer do
  @moduledoc """
  File Transfer Command Settings

  OSDP v2.2 Specification Reference: 6.26
  """

  defstruct type: 1,
            total_size: 0,
            offset: 0,
            fragment_size: 0,
            data: <<>>

  @type t :: %__MODULE__{
          type: 1..255,
          total_size: pos_integer(),
          offset: pos_integer(),
          data: binary(),
          fragment_size: pos_integer()
        }

  @type param() ::
          {:type, 1..255}
          | {:total_size, pos_integer()}
          | {:offset, pos_integer()}
          | {:fragment_size, pos_integer()}
          | {:data, binary()}
  @type params() :: t() | [param()]

  @spec new(params()) :: t()
  def new(params) do
    struct(__MODULE__, params)
  end

  @spec encode(params()) :: <<_::64>>
  def encode(params) do
    settings = new(params)

    <<
      settings.type,
      settings.total_size::size(4)-unit(8)-little,
      settings.offset::size(4)-unit(8)-little,
      settings.fragment_size::size(2)-unit(8)-little,
      settings.data::binary
    >>
  end

  @doc """
  Create set of FileTransfer commands to run

  FileTransfers may require multiple command/reply pairs in order to transmit
  all the data to the PD. This function helps chunk the data according to the
  max byte length allowed by the PD. In most cases, you would run
  `Jeff.capabilities/2` before this check for the Receive Buffer size reported
  by the PD and use that as the max value.

  The first message will always be 128 bytes of data if the max value is larger

  You can then cycle through sending these commands and check the returned
  FTSTAT reply (%Jeff.Reply.FileTransferStatus{}) with `adjust_from_reply/2` to
  adjust the command set as needed
  """
  @spec command_set(binary(), pos_integer()) :: [t()]
  def command_set(data, max \\ 128) do
    base = new(total_size: byte_size(data))
    chunk_data(data, base, max, [])
  end

  @doc """
  Adjust file transfer command set based on the FTSTAT reply

  Mostly used internally to potentially adjust the remaining command set
  based on the FTSTAT reply from the previous command. In some cases the
  next set of commands may need to be adjusted or prevented and this provides
  the functional core to make that decision
  """
  @spec adjust_from_reply(Jeff.Reply.t(), [t()]) ::
          {:cont, [t()], pos_integer()}
          | {:halt, Jeff.Reply.FileTransferStatus.t() | Jeff.Reply.ErrorCode.t()}
  def adjust_from_reply(%{name: NAK, data: error_code}, _commands), do: {:halt, error_code}
  def adjust_from_reply(%{name: FTSTAT, data: ftstat}, []), do: {:halt, ftstat}

  def adjust_from_reply(%{name: FTSTAT, data: %{status: :finishing} = ftstat}, commands) do
    # OSDP v2.2 Section 7.25
    # Finishing status requires we send an "idle" message until we get a different
    # status. In idle message, fragment size == 0 and offset == total size
    idle = hd(commands)
    commands = maybe_adjust_message_size(ftstat, commands)
    {:cont, [%{idle | fragment_size: 0, offset: idle.total_size} | commands], ftstat.delay}
  end

  def adjust_from_reply(%{name: FTSTAT, data: %{status: status} = ftstat}, commands)
      when status in [:ok, :processed, :rebooting] do
    {:cont, maybe_adjust_message_size(ftstat, commands), ftstat.delay}
  end

  def adjust_from_reply(%{name: FTSTAT, data: ftstat}, _commands), do: {:halt, ftstat}

  defp maybe_adjust_message_size(%{update_msg_max: max}, commands)
       when not is_nil(max) and max > 0 do
    base = hd(commands)
    data = for %{data: d} <- commands, into: <<>>, do: d
    chunk_data(data, base, max, [])
  end

  defp maybe_adjust_message_size(_ftstat, commands), do: commands

  defp chunk_data(data, _base, _max, acc) when byte_size(data) == 0 do
    Enum.reverse(acc)
  end

  defp chunk_data(<<data::binary-128, rest::binary>>, base, max, []) when max >= 128 do
    # First command must be 128 bytes in cases where the PD max receive buffer is
    # more than 128
    chunk_data(rest, base, max, [%{base | data: data, fragment_size: 128}])
  end

  defp chunk_data(data, base, max, acc) when byte_size(data) >= max do
    <<frag::binary-size(max), rest::binary>> = data
    cmd = %{base | data: frag, fragment_size: max, offset: next_offset(base, acc)}
    chunk_data(rest, base, max, [cmd | acc])
  end

  defp chunk_data(data, base, _max, acc) do
    frag_size = byte_size(data)
    # cmd = new(total_size: total, data: data, fragment_size: frag_size, offset: o + frag_size)
    cmd = %{base | data: data, fragment_size: frag_size, offset: next_offset(base, acc)}
    Enum.reverse([cmd | acc])
  end

  # Start from the base offset
  defp next_offset(%{offset: o}, []) when is_integer(o), do: o
  # First command and no base offset, use 0
  defp next_offset(_base, []), do: 0
  # offset from the last command
  defp next_offset(_base, [%{offset: o, fragment_size: fs} | _]), do: o + fs
end

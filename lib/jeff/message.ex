defmodule Jeff.Message do
  alias Jeff.ControlInfo
  import Jeff.ErrorChecks

  @som 0x53

  @broadcast_address 0x7F
  @default_code 0x60

  defstruct address: @broadcast_address,
            length: 0,
            sequence_number: 0,
            check_scheme: :checksum,
            security_control_block?: false,
            code: @default_code,
            mac: nil,
            check: nil,
            bytes: <<>>

  @spec new(keyword()) :: %__MODULE__{}
  def new(options \\ []) do
    struct(__MODULE__, options) |> build()
  end

  defp build(message) do
    message
    |> add_start_of_message()
    |> add_address()
    |> add_message_length()
    |> add_message_control_info()
    # |> maybe_add_security_block_length()
    # |> maybe_add_security_block_type()
    # |> maybe_add_security_block_data()
    |> add_command_or_reply_code()
    # |> maybe_add_data()
    # |> maybe_add_mac()
    |> calculate_message_length()
    |> add_check()
  end

  defp add_start_of_message(message) do
    %{message | bytes: <<@som>>}
  end

  defp add_address(%{bytes: bytes, address: address} = message) do
    %{message | bytes: bytes <> <<address>>}
  end

  defp add_message_length(%{bytes: bytes} = message) do
    %{message | bytes: bytes <> <<0, 0>>}
  end

  defp add_message_control_info(%{bytes: bytes} = message) do
    options = [
      sequence_number: message.sequence_number,
      check_scheme: message.check_scheme,
      security_control_block?: message.security_control_block?
    ]

    %{byte: byte} = ControlInfo.new(options)

    message
    |> struct(options)
    |> struct(bytes: bytes <> <<byte>>)
  end

  defp add_command_or_reply_code(%{bytes: bytes} = message) do
    %{message | bytes: bytes <> <<message.code>>}
  end

  defp calculate_message_length(%{bytes: bytes} = message) do
    packet_length = byte_size(bytes) + check_size(message)
    <<head::size(16), _packet_length::size(16), rest::binary>> = bytes
    bytes = <<head::size(16), packet_length::size(16)-little>> <> rest
    %{message | bytes: bytes, length: packet_length}
  end

  defp check_size(%{check_scheme: :checksum}), do: 1
  defp check_size(%{check_scheme: :crc}), do: 2

  defp add_check(%{check_scheme: :checksum, bytes: bytes} = message) do
    check = checksum(bytes)
    %{message | bytes: bytes <> <<check>>, check: check}
  end

  defp add_check(%{check_scheme: :crc, bytes: bytes} = message) do
    check = crc(bytes)
    %{message | bytes: bytes <> <<check::size(16)-little>>, check: check}
  end

  @spec from_bytes(binary()) :: %__MODULE__{}
  def from_bytes(bytes) when is_binary(bytes) do
    <<@som, addr, len::size(16)-little, mci, _rest::binary>> = bytes

    mci = ControlInfo.from_byte(mci)

    [
      address: addr,
      length: len,
      sequence_number: mci.sequence_number,
      check_scheme: mci.check_scheme,
      security_control_block?: mci.security_control_block?
    ]
    |> new()
  end

  def start_of_message, do: @som
end

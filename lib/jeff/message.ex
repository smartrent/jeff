defmodule Jeff.Message do
  @moduledoc false

  alias Jeff.{ControlInfo, SecureChannel}
  import Jeff.ErrorChecks

  @som 0x53
  @mac_sb_types [0x15, 0x16, 0x17, 0x18]

  defstruct [
    :address,
    :code,
    :security?,
    :sequence,
    :check_scheme,
    :sb_type,
    :sb_data,
    :data,
    :mac,
    :length,
    :check,
    :bytes,
    :device
  ]

  @spec new(keyword()) :: %__MODULE__{}
  def new(options \\ []) do
    struct(__MODULE__, options)
    |> encode()
  end

  def new(device, command) do
    security? = if device.sequence == 0, do: false, else: device.security?

    sb_type = scs(device.address, command.code, device.secure_channel.established?)

    sb_data =
      if device.secure_channel.established? do
        <<>>
      else
        case device.secure_channel.scbkd? do
          true -> 0
          false -> 1
        end
      end

    data =
      if device.secure_channel.established? && command.data && byte_size(command.data) > 1 do
        SecureChannel.encrypt(device.secure_channel, command.data)
      else
        command.data
      end

    new(
      address: device.address,
      check_scheme: device.check_scheme,
      sequence: device.sequence,
      security?: security?,
      sb_type: sb_type,
      sb_data: sb_data,
      code: command.code,
      data: data,
      device: device
    )
  end

  defp encode(message) do
    message
    |> add_start_of_message()
    |> add_address()
    |> add_message_length()
    |> add_message_control_info()
    |> maybe_add_security_block()
    |> add_command_or_reply_code()
    |> maybe_add_data()
    |> calculate_message_length()
    |> maybe_add_mac()
    |> add_check()
  end

  def type(%{address: address} = _message), do: type(address)

  def type(address) when is_integer(address) do
    <<reply?::1, _::7>> = <<address>>
    if reply? == 1, do: :reply, else: :command
  end

  def scs(address, code, sc_established?) do
    do_scs(type(address), code, sc_established?)
  end

  defp do_scs(:command, 0x76, _), do: 0x11
  defp do_scs(:reply, 0x76, _), do: 0x12
  defp do_scs(:command, 0x77, _), do: 0x13
  defp do_scs(:reply, 0x78, _), do: 0x14
  defp do_scs(:command, _, true), do: 0x17
  defp do_scs(:reply, _, true), do: 0x18
  defp do_scs(:command, _, false), do: nil
  defp do_scs(:reply, _, false), do: nil

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
    byte = ControlInfo.encode(message)
    %{message | bytes: bytes <> <<byte>>}
  end

  defp maybe_add_security_block(%{security?: false} = message), do: message

  defp maybe_add_security_block(%{security?: true, bytes: bytes} = message) do
    %{sb_type: sb_type, sb_data: sb_data} = message
    sb = [sb_type, sb_data] |> :binary.list_to_bin()
    sb_len = byte_size(sb) + 1
    sb = <<sb_len>> <> sb

    %{message | bytes: bytes <> sb}
  end

  defp add_command_or_reply_code(%{bytes: bytes} = message) do
    %{message | bytes: bytes <> <<message.code>>}
  end

  defp maybe_add_data(%{data: nil} = message), do: message

  defp maybe_add_data(%{data: data, bytes: bytes} = message) do
    %{message | bytes: bytes <> data}
  end

  defp maybe_add_mac(%{bytes: bytes, device: device} = message) do
    {secure_channel, mac} =
      if add_mac?(message) do
        secure_channel = SecureChannel.calculate_mac(device.secure_channel, bytes, true)
        {secure_channel, secure_channel.cmac |> :binary.part(0, 4)}
      else
        {device.secure_channel, <<>>}
      end

    device = %{device | secure_channel: secure_channel}

    %{message | bytes: bytes <> mac, mac: mac, device: device}
  end

  defp add_mac?(%{sb_type: sb_type}) when sb_type in @mac_sb_types do
    true
  end

  defp add_mac?(_message), do: false

  def mac_size(message), do: if(add_mac?(message), do: 4, else: 0)

  defp calculate_message_length(%{bytes: bytes} = message) do
    packet_length = byte_size(bytes) + check_size(message) + mac_size(message)
    <<head::size(16), _packet_length::size(16), rest::binary>> = bytes
    bytes = <<head::size(16), packet_length::size(16)-little>> <> rest
    %{message | bytes: bytes, length: packet_length}
  end

  def check_size(%{check_scheme: check_scheme}) do
    do_check_size(check_scheme)
  end

  defp do_check_size(:checksum), do: 1
  defp do_check_size(:crc), do: 2

  defp add_check(%{check_scheme: :checksum, bytes: bytes} = message) do
    check = checksum(bytes)
    %{message | bytes: bytes <> <<check>>, check: check}
  end

  defp add_check(%{check_scheme: :crc, bytes: bytes} = message) do
    check = crc(bytes)
    %{message | bytes: bytes <> <<check::size(16)-little>>, check: check}
  end

  @spec decode(binary()) :: %__MODULE__{}
  def decode(<<@som, rest::binary>> = bytes) do
    do_decode(rest, %__MODULE__{bytes: bytes})
  end

  def do_decode(bytes, %{address: nil} = message) do
    <<address, rest::binary>> = bytes
    do_decode(rest, %{message | address: address})
  end

  def do_decode(bytes, %{length: nil} = message) do
    <<length::size(16)-little, rest::binary>> = bytes
    do_decode(rest, %{message | length: length})
  end

  def do_decode(bytes, %{sequence: nil} = message) do
    <<control_byte, rest::binary>> = bytes

    {sequence, check_scheme, security?} = ControlInfo.decode(control_byte)

    message = %{message | sequence: sequence, check_scheme: check_scheme, security?: security?}

    do_decode(rest, message)
  end

  def do_decode(bytes, %{security?: true, sb_type: nil} = message) do
    sb_len = :binary.at(bytes, 0)
    <<sb::binary-size(sb_len), rest::binary>> = bytes
    <<_sb_len, sb_type, sb_data::binary>> = sb
    message = %{message | sb_type: sb_type, sb_data: sb_data}
    do_decode(rest, message)
  end

  def do_decode(bytes, %{code: nil} = message) do
    <<code, rest::binary>> = bytes
    do_decode(rest, %{message | code: code})
  end

  def do_decode(bytes, %{data: nil} = message) do
    data_size = byte_size(bytes) - check_size(message) - mac_size(message)

    <<data::binary-size(data_size), rest::binary>> = bytes
    do_decode(rest, %{message | data: data})
  end

  def do_decode(bytes, %{mac: nil, sb_type: sb_type} = message) when sb_type in @mac_sb_types do
    <<mac::binary-size(4), rest::binary>> = bytes
    do_decode(rest, %{message | mac: mac})
  end

  def do_decode(bytes, %{check_scheme: :checksum} = message) do
    <<check::size(8)-little>> = bytes
    %{message | check: check}
  end

  def do_decode(bytes, %{check_scheme: :crc} = message) do
    <<check::size(16)-little>> = bytes
    %{message | check: check}
  end

  def start_of_message, do: @som
end

defmodule MessageTest do
  use ExUnit.Case

  alias Jeff.{Message, ControlInfo}
  import Jeff.ErrorChecks

  @som Message.start_of_message()

  test "building a new message" do
    address = 0x23
    code = 0x42
    check_scheme = :checksum

    message =
      Message.new(
        address: address,
        code: code,
        check_scheme: check_scheme
      )

    mci = ControlInfo.new(message |> Map.from_struct()).byte

    bytes = <<@som, address, 7::size(16)-little, mci, code>>
    check = checksum(bytes)
    bytes = bytes <> <<check>>

    assert Base.encode16(bytes) == Base.encode16(message.bytes)
    assert byte_size(message.bytes) == 7
    assert message.length == 7
  end

  test "build with crc" do
    message = Message.new(check_scheme: :crc)

    <<_som, _addr, packet_length::size(16)-little, _rest::binary>> = message.bytes
    assert packet_length == byte_size(message.bytes)
    assert packet_length == message.length
    assert packet_length == 8
    assert message.check_scheme == :crc

    <<msg_without_crc::size(48), check::size(16)-little>> = message.bytes
    assert check == crc(<<msg_without_crc::size(48)>>)
  end

  test "build from bytes" do
    address = 0xFF
    code = 0x65

    mci =
      ControlInfo.new(
        sequence_number: 3,
        security_control_block?: false,
        check_scheme: :crc
      ).byte

    message = Message.from_bytes(<<@som, address, 8::size(16)-little, mci, code, 1, 68>>)
    assert message.address == 0xFF
    assert message.length == 8
    assert message.sequence_number == 3
    assert message.security_control_block? == false
    assert message.check_scheme == :crc
  end
end

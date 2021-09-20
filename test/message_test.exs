defmodule MessageTest do
  use ExUnit.Case

  alias Jeff.{Command, Device, Message}

  test "building a new message" do
    device =
      Device.new(
        address: 0x23,
        security?: false,
        check_scheme: :crc
      )

    command = Command.new(0x23, POLL)
    message = Message.new(device, command)

    assert %{
             address: 0x23,
             code: 0x60,
             security?: false,
             check_scheme: :crc,
             sequence: 0,
             length: 8,
             check: 19597,
             bytes: <<83, 35, 8, 0, 4, 96, 141, 76>>
           } = message
  end

  test "build from bytes" do
    bytes = <<0x53, 0xFF, 0x08, 0x00, 0x07, 0x65, 0x01, 0x44>>

    message = Message.decode(bytes)
    assert message.address == 0xFF
    assert message.length == 8
    assert message.sequence == 3
    assert message.security? == false
    assert message.check_scheme == :crc
    assert message.code == 0x65
    assert message.bytes == bytes
  end

  test "build a message with data from bytes" do
    message =
      <<0x53, 0x01, 0x09, 0x00, 0x05, 0x61, 0x00, 0x50, 0x14>>
      |> Message.decode()

    assert message.address == 0x1
    assert message.length == 9
    assert message.code == 0x61
    assert message.data == <<0x00>>
  end

  test "determining message type" do
    # command address 0x00 - 0x7F
    assert Message.type(%Message{address: 0x1}) == :command

    # reply address = command address + reply flag (0x80)
    assert Message.type(%Message{address: 0x1 + 0x80}) == :reply
  end

  test "determining secure connection sequence" do
    # CHLNG command
    assert Message.scs(0x1, 0x76, false) == 0x11

    # CCRYPT reply
    assert Message.scs(0x1 + 0x80, 0x76, false) == 0x12

    # SCRYPT command
    assert Message.scs(0x1, 0x77, false) == 0x13

    # RMAC-I reply
    assert Message.scs(0x1 + 0x80, 0x78, false) == 0x14

    # Any other command - established secure channel
    assert Message.scs(0x1, 0x60, true) == 0x17

    # Any other reply - established secure channel
    assert Message.scs(0x1 + 0x80, 0x40, true) == 0x18

    # Any other command - non-established secure channel
    assert Message.scs(0x1, 0x60, false) == nil

    # Any other reply - non-established secure channel
    assert Message.scs(0x1 + 0x80, 0x40, false) == nil
  end

  test "decode message with mac" do
    _message = Message.decode(<<83, 129, 14, 0, 15, 2, 22, 64, 12, 73, 225, 102, 51, 242>>)
  end
end

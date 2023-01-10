defmodule DeviceTest do
  use ExUnit.Case

  alias Jeff.{Command, Device}

  test "creating a new device - defaults" do
    device = Device.new()
    assert device.address == 0x7F
    assert device.sequence == 0
    assert device.check_scheme == :checksum
    assert device.security? == false
  end

  test "creating a new device - setting constructor options" do
    device = Device.new(address: 0x01, check_scheme: :crc)
    assert device.address == 0x01
    assert device.check_scheme == :crc
  end

  test "incrementing sequence numbers" do
    device = Device.new()
    assert device.sequence == 0
    assert device = Device.inc_sequence(device)
    assert device.sequence == 1
    assert device = Device.inc_sequence(device)
    assert device.sequence == 2
    assert device = Device.inc_sequence(device)
    assert device.sequence == 3
    assert device = Device.inc_sequence(device)
    assert device.sequence == 1
  end

  test "reset device communication" do
    device = Device.new()
    assert device.sequence == 0
    assert device = Device.inc_sequence(device)
    assert device.sequence == 1
    assert device = Device.inc_sequence(device)
    assert device.sequence == 2

    secure_channel = device.secure_channel

    assert device = Device.reset(device)
    assert device.sequence == 0
    assert device.last_valid_reply == 0
    assert device.secure_channel != secure_channel
  end

  test "send commands" do
    command = Command.new(0x01, POLL)
    device = Device.new()
    assert device.commands == {[], []}
    device = Device.send_command(device, command)
    assert device.commands == {[command], []}
  end

  test "next command is POLL if sequence is 0" do
    queued_command = Command.new(0x01, ID)
    poll_command = Command.new(0x01, POLL)
    device = Device.new(address: 0x01)
    device = Device.send_command(device, queued_command)
    assert device.sequence == 0

    {_device, next_command} = Device.next_command(device)

    assert next_command == poll_command
  end

  test "next command is CHLNG if security not initialized" do
    device = Device.new() |> Device.inc_sequence()
    assert device.sequence == 1

    device = %{device | security?: true}
    assert device.secure_channel.initialized? == false

    {_device, next_command} = Device.next_command(device)
    assert next_command.name == CHLNG
  end

  test "next command is CHLNG if security not established" do
    device = Device.new() |> Device.inc_sequence()
    assert device.sequence == 1

    device = %{device | security?: true}
    device = %{device | secure_channel: %{device.secure_channel | initialized?: true}}
    assert device.security? == true
    assert device.secure_channel.initialized? == true
    assert device.secure_channel.established? == false

    {_device, next_command} = Device.next_command(device)
    assert next_command.name == SCRYPT
  end

  test "next command is KEYSET if security is established in install mode" do
    device = Device.new(scbk: :rand.bytes(16)) |> Device.inc_sequence()
    assert device.sequence == 1

    device = %{device | security?: true, install_mode?: true}

    device = %{
      device
      | secure_channel: %{
          device.secure_channel
          | initialized?: true,
            established?: true,
            scbkd?: true
        }
    }

    {_device, next_command} = Device.next_command(device)
    assert next_command.name == KEYSET
  end

  test "next command is POLL if command queue is empty" do
    poll_command = Command.new(0x01, POLL)
    device = Device.new(address: 0x01) |> Device.inc_sequence()
    assert device.sequence == 1

    {_device, next_command} = Device.next_command(device)

    assert next_command == poll_command
  end

  test "next command is first sent command if no other conditions are met" do
    poll_command = Command.new(0x01, POLL)
    device = Device.new(address: 0x01) |> Device.inc_sequence()
    assert device.sequence == 1
    command1 = %Command{code: 0x4}
    command2 = %Command{code: 0x8}
    device = Device.send_command(device, command1)
    device = Device.send_command(device, command2)

    assert {device, ^command1} = Device.next_command(device)
    assert {device, ^command2} = Device.next_command(device)
    assert {_device, ^poll_command} = Device.next_command(device)
  end

  test "receiving a valid reply" do
    device = Device.new()
    assert device.sequence == 0
    assert device.last_valid_reply == nil

    # increment sqn, do not set last_valid_reply when incrementing from zero
    device = Device.receive_valid_reply(device)
    assert device.sequence == 1
    assert device.last_valid_reply == nil

    # increment sqn, set last_valid_reply when incrementing non-zero numbers
    device = Device.receive_valid_reply(device)
    assert device.sequence == 2
    assert_in_delta device.last_valid_reply, System.monotonic_time(:millisecond), 100
  end

  test "online?" do
    now = System.monotonic_time(:millisecond)
    eight_secs = 8000

    assert %Device{last_valid_reply: nil} |> Device.online?() == false
    assert %Device{last_valid_reply: now} |> Device.online?() == true
    assert %Device{last_valid_reply: now + eight_secs} |> Device.online?() == false
  end
end

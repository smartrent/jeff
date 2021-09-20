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
end

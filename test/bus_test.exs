defmodule BusTest do
  use ExUnit.Case

  alias Jeff.{Bus, Command, Reply}

  test "adding a device" do
    address = 0x23
    bus = Bus.new()

    bus = Bus.add_device(bus, address: address)
    assert Bus.get_device(bus, address).address == address
  end

  test "registered?" do
    address = 0x23
    bus = Bus.new()

    refute Bus.registered?(bus, address)
    bus = Bus.add_device(bus, address: address)
    assert Bus.registered?(bus, address)
  end

  test "sending a command" do
    address = 0x23
    command = Command.new(address, POLL)

    bus = Bus.new()
    bus = Bus.add_device(bus, address: address)
    bus = Bus.send_command(bus, command)
    device = Bus.get_device(bus, address)
    assert device.commands == {[command], []}
  end

  test "receiving a reply" do
    reply = Reply.new(0x01, ACK)
    bus = Bus.new()

    bus = Bus.receive_reply(bus, reply)
    assert bus.reply == reply
  end

  test "tick" do
    bus = Bus.new()
    bus = Bus.add_device(bus, address: 0x1)
    bus = Bus.add_device(bus, address: 0x2)
    bus = Bus.add_device(bus, address: 0x3)
    assert bus.cursor == nil

    bus = Bus.tick(bus)
    assert bus.poll == [0x1, 0x2, 0x3]
    assert bus.cursor == nil
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == [0x2, 0x3]
    assert bus.cursor == 0x1
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == [0x2, 0x3]
    assert bus.cursor == 0x1
    assert bus.command == Command.new(0x01, POLL)
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == [0x2, 0x3]
    assert bus.cursor == 0x1
    assert bus.command == Command.new(0x01, POLL)
    assert bus.reply == nil

    bus = Bus.receive_reply(bus, Reply.new(0x01, ACK))
    assert bus.poll == [0x2, 0x3]
    assert bus.cursor == 0x1
    assert bus.command == Command.new(0x01, POLL)
    assert bus.reply == Reply.new(0x01, ACK)

    bus = Bus.tick(bus)
    assert bus.poll == [0x2, 0x3]
    assert bus.cursor == nil
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == [0x3]
    assert bus.cursor == 0x2
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == [0x3]
    assert bus.cursor == 0x2
    assert bus.command == Command.new(0x02, POLL)
    assert bus.reply == nil

    bus = Bus.receive_reply(bus, Reply.new(0x02, ACK))
    assert bus.poll == [0x3]
    assert bus.cursor == 0x2
    assert bus.command == Command.new(0x02, POLL)
    assert bus.reply == Reply.new(0x02, ACK)

    bus = Bus.tick(bus)
    assert bus.poll == [0x3]
    assert bus.cursor == nil
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == []
    assert bus.cursor == 0x3
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == []
    assert bus.cursor == 0x3
    assert bus.command == Command.new(0x03, POLL)
    assert bus.reply == nil

    bus = Bus.receive_reply(bus, Reply.new(0x03, ACK))
    assert bus.poll == []
    assert bus.cursor == 0x3
    assert bus.command == Command.new(0x03, POLL)
    assert bus.reply == Reply.new(0x03, ACK)

    bus = Bus.tick(bus)
    assert bus.poll == []
    assert bus.cursor == nil
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == [0x1, 0x2, 0x3]
    assert bus.cursor == nil
    assert bus.command == nil
    assert bus.reply == nil
  end

  test "tick with a sent command" do
    poll_command = Command.new(0x01, POLL)
    ack_reply = Reply.new(0x01, ACK)
    id_command = Command.new(0x01, ID)
    pdid_reply = Reply.new(0x01, PDID_TEST)

    bus = Bus.new()
    bus = Bus.add_device(bus, address: 0x01)
    bus = Bus.send_command(bus, id_command)

    bus = Bus.tick(bus)
    assert bus.poll == [0x1]
    assert bus.cursor == nil
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == []
    assert bus.cursor == 0x1
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == []
    assert bus.cursor == 0x1
    assert bus.command == poll_command
    assert bus.reply == nil

    bus = Bus.receive_reply(bus, ack_reply)
    assert bus.poll == []
    assert bus.cursor == 0x1
    assert bus.command == poll_command
    assert bus.reply == ack_reply

    bus = Bus.tick(bus)
    assert bus.poll == []
    assert bus.cursor == nil
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == [0x1]
    assert bus.cursor == nil
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == []
    assert bus.cursor == 0x1
    assert bus.command == nil
    assert bus.reply == nil

    bus = Bus.tick(bus)
    assert bus.poll == []
    assert bus.cursor == 0x1
    assert bus.command == id_command
    assert bus.reply == nil

    bus = Bus.receive_reply(bus, pdid_reply)
    assert bus.poll == []
    assert bus.cursor == 0x1
    assert bus.command == id_command
    assert bus.reply == pdid_reply

    bus = Bus.tick(bus)
    assert bus.poll == []
    assert bus.cursor == nil
    assert bus.command == nil
    assert bus.reply == nil
  end
end

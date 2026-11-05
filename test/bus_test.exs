defmodule BusTest do
  use ExUnit.Case

  alias Jeff.{Bus, Command, Message, Reply, SecureChannel}
  alias Jeff.Reply.EncryptionClient

  test "adding a device" do
    address = 0x23
    bus = Bus.new()

    bus = Bus.add_device(bus, address: address)
    assert Bus.get_device(bus, address).address == address
  end

  test "removing a device" do
    address = 0x23
    bus = Bus.new()

    bus = Bus.add_device(bus, address: address)
    bus = Bus.tick(bus)
    assert address in bus.poll
    assert Bus.registered?(bus, address)

    bus = Bus.remove_device(bus, address)
    refute address in bus.poll
    refute Bus.registered?(bus, address)
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

  # Drives the bus through one full poll cycle for a single-device bus, the same
  # way Jeff.ACU does: tick until a command is ready, encode it, deliver the
  # reply, then tick to handle the reply. Returns the bus and the sent message.
  defp poll_cycle(bus, reply) do
    bus = bus |> Bus.tick() |> Bus.tick() |> Bus.tick()
    message = Message.new(Bus.current_device(bus), bus.command)
    bus = bus |> Bus.receive_reply(reply) |> Bus.tick()
    {bus, message}
  end

  defp next_message(bus) do
    bus = bus |> Bus.tick() |> Bus.tick() |> Bus.tick()
    Message.new(Bus.current_device(bus), bus.command)
  end

  describe "sequence numbers" do
    setup do
      bus = Bus.new() |> Bus.add_device(address: 0x01)
      %{bus: bus, ack: Reply.new(0x01, ACK)}
    end

    test "advance on valid replies", %{bus: bus, ack: ack} do
      {bus, m0} = poll_cycle(bus, ack)
      {bus, m1} = poll_cycle(bus, ack)
      {bus, m2} = poll_cycle(bus, ack)
      {bus, m3} = poll_cycle(bus, ack)
      {_bus, m4} = poll_cycle(bus, ack)

      assert Enum.map([m0, m1, m2, m3, m4], & &1.sequence) == [0, 1, 2, 3, 1]
    end

    test "do not advance on timeout", %{bus: bus, ack: ack} do
      {bus, _} = poll_cycle(bus, ack)
      {bus, m1} = poll_cycle(bus, :timeout)
      {_bus, m2} = poll_cycle(bus, :timeout)

      assert m1.sequence == 1
      assert m2.sequence == 1
    end

    test "NAK unexpected sequence number resets the next command to sequence 0",
         %{bus: bus, ack: ack} do
      nak = Reply.new(0x01, NAK, <<0x04>>)

      {bus, _} = poll_cycle(bus, ack)
      {bus, _} = poll_cycle(bus, ack)
      {bus, m2} = poll_cycle(bus, nak)
      assert m2.sequence == 2

      assert next_message(bus).sequence == 0
    end

    test "NAK reset sends the queued command next, at sequence 0", %{bus: bus, ack: ack} do
      {bus, _} = poll_cycle(bus, ack)
      {bus, _} = poll_cycle(bus, ack)

      # POLL at sequence 2 is in flight when the application queues a command
      bus = bus |> Bus.tick() |> Bus.tick() |> Bus.tick()
      assert bus.command.name == POLL
      assert Message.new(Bus.current_device(bus), bus.command).sequence == 2

      caller = make_ref()
      queued = Command.new(0x01, ID, caller: caller)
      bus = Bus.send_command(bus, queued)

      bus = bus |> Bus.receive_reply(Reply.new(0x01, NAK, <<0x04>>)) |> Bus.tick()

      bus = bus |> Bus.tick() |> Bus.tick() |> Bus.tick()
      assert bus.command == queued
      assert bus.command.caller == caller
      assert Message.new(Bus.current_device(bus), bus.command).sequence == 0
    end

    test "NAK reset on a secure device restarts the handshake with CHLNG at sequence 0",
         %{ack: ack} do
      bus = Bus.new() |> Bus.add_device(address: 0x01, security?: true)
      bus = establish_secure_channel(bus, ack)

      {bus, m} = poll_cycle(bus, Reply.new(0x01, NAK, <<0x04>>))
      assert {m.code, m.sequence, m.security?} == {0x60, 2, true}

      # Whether the CHLNG at sequence 0 carries a security block is decided by
      # Message.new/2 (pre-existing behavior), so it is not asserted here.
      bus = bus |> Bus.tick() |> Bus.tick() |> Bus.tick()
      assert bus.command.name == CHLNG
      assert Message.new(Bus.current_device(bus), bus.command).sequence == 0
      refute Bus.current_device(bus).secure_channel.initialized?
      refute Bus.current_device(bus).secure_channel.established?
    end

    test "NAK reset resets the secure channel", %{ack: ack} do
      bus = Bus.new() |> Bus.add_device(address: 0x01)
      {bus, _} = poll_cycle(bus, ack)

      device = Bus.get_device(bus, 0x01)
      channel = %{device.secure_channel | initialized?: true}
      bus = Bus.put_device(bus, 0x01, %{device | secure_channel: channel})

      {bus, _} = poll_cycle(bus, Reply.new(0x01, NAK, <<0x04>>))

      device = Bus.get_device(bus, 0x01)
      assert device.sequence == 0
      refute device.secure_channel.initialized?
    end

    test "other NAKs still advance the sequence", %{bus: bus, ack: ack} do
      {bus, _} = poll_cycle(bus, ack)
      {bus, m1} = poll_cycle(bus, Reply.new(0x01, NAK, <<0x03>>))

      assert m1.sequence == 1
      assert next_message(bus).sequence == 2
    end

    test "communication restarts at sequence 0 after a NAK reset", %{bus: bus, ack: ack} do
      {bus, _} = poll_cycle(bus, ack)
      {bus, _} = poll_cycle(bus, Reply.new(0x01, NAK, <<0x04>>))
      {bus, m0} = poll_cycle(bus, ack)
      {_bus, m1} = poll_cycle(bus, ack)

      assert m0.sequence == 0
      assert m1.sequence == 1
    end
  end

  # Runs the CHLNG/SCRYPT handshake for the single secure device at 0x01 using
  # the default SCBK (SCBK-D), applying the secure channel updates that Jeff.ACU
  # makes on CCRYPT and RMAC_I. Leaves the device at sequence 2 with an
  # established secure channel.
  defp establish_secure_channel(bus, reply) do
    bus = bus |> Bus.tick() |> Bus.tick() |> Bus.tick()
    assert bus.command.name == CHLNG
    assert Message.new(Bus.current_device(bus), bus.command).sequence == 0

    device = Bus.current_device(bus)
    sc = device.secure_channel
    client_rnd = <<1, 2, 3, 4, 5, 6, 7, 8>>
    enc = SecureChannel.gen_enc(sc.server_rnd, sc.scbk)
    cryptogram = SecureChannel.gen_client_cryptogram(sc.server_rnd, client_rnd, enc)
    ccrypt = %EncryptionClient{cuid: <<0::64>>, rnd: client_rnd, cryptogram: cryptogram}
    device = %{device | secure_channel: SecureChannel.initialize(sc, ccrypt)}
    bus = bus |> Bus.put_device(device) |> Bus.receive_reply(reply) |> Bus.tick()

    bus = bus |> Bus.tick() |> Bus.tick() |> Bus.tick()
    assert bus.command.name == SCRYPT
    assert Message.new(Bus.current_device(bus), bus.command).sequence == 1

    device = Bus.current_device(bus)
    sc = SecureChannel.establish(device.secure_channel, <<0::128>>)
    bus = Bus.put_device(bus, %{device | secure_channel: sc})
    bus |> Bus.receive_reply(reply) |> Bus.tick()
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
    assert bus.command == id_command
    assert bus.reply == nil

    bus = Bus.receive_reply(bus, ack_reply)
    assert bus.poll == []
    assert bus.cursor == 0x1
    assert bus.command == id_command
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
    assert bus.command == poll_command
    assert bus.reply == nil

    bus = Bus.receive_reply(bus, pdid_reply)
    assert bus.poll == []
    assert bus.cursor == 0x1
    assert bus.command == poll_command
    assert bus.reply == pdid_reply

    bus = Bus.tick(bus)
    assert bus.poll == []
    assert bus.cursor == nil
    assert bus.command == nil
    assert bus.reply == nil
  end
end

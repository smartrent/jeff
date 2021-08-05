defmodule FramingTest do
  use ExUnit.Case

  alias Jeff.Framing

  @mark 0xFF

  test "framing a message packet header" do
    new_state = %Framing.State{}
    packet = <<0x53, 0x7F, 0x05, 0x00, 0x23>>
    data = <<@mark>> <> packet

    assert Framing.remove_framing(data, new_state) == {:ok, [packet], new_state}
  end

  test "waiting for start of message after marking line" do
    new_state = %Framing.State{}
    packet = <<0x53, 0x7F, 0x05, 0x00, 0x23>>
    data = <<@mark, @mark, @mark>> <> packet

    assert Framing.remove_framing(data, new_state) == {:ok, [packet], new_state}
  end

  test "framing two messages" do
    new_state = %Framing.State{}
    packet1 = <<0x53, 0x7F, 0x05, 0x00, 0x23>>
    packet2 = <<0x53, 0x7F, 0x05, 0x00, 0x42>>
    data = <<@mark>> <> packet1 <> <<@mark>> <> packet2

    assert Framing.remove_framing(data, new_state) ==
             {:ok, [packet1, packet2], new_state}
  end

  test "returning partial packets in the buffer" do
    new_state = %Framing.State{}
    partial_packet = <<0x53, 0x7F, 0x06, 0x00, 0x23>>
    data = <<@mark>> <> partial_packet

    assert Framing.remove_framing(data, new_state) ==
             {:in_frame, [], %Framing.State{buffer: partial_packet, packet_length: 6}}
  end

  test "returning a packet and partial packet" do
    new_state = %Framing.State{}
    packet = <<0x53, 0x7F, 0x06, 0x00, 0x23, 0x42>>
    partial_packet = <<0x53, 0x7F, 0x8, 0x00, 0x23>>
    data = <<@mark>> <> packet <> <<@mark>> <> partial_packet

    assert Framing.remove_framing(data, new_state) ==
             {:in_frame, [packet], %Framing.State{buffer: partial_packet, packet_length: 8}}
  end
end

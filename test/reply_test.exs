defmodule ReplyTest do
  use ExUnit.Case

  alias Jeff.{Message, Reply}

  test "build a new reply from a message" do
    reply = Reply.new(%Message{address: 0x01, code: 0x40, data: nil})
    assert %{code: 0x40, name: ACK, data: nil} = reply
  end

  test "build a new reply from module" do
    reply = Reply.new(0x01, ACK)
    assert %{address: 0x01, code: 0x40, name: ACK, data: nil} = reply
  end

  test "build a reply with an unknown code" do
    reply = Reply.new(%Message{address: 0x01, code: 0xFF, data: <<0x23>>})
    assert %{address: 0x01, code: 0xFF, name: UNKNOWN, data: <<0x23>>} = reply
  end
end

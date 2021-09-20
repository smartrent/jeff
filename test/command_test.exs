defmodule CommandTest do
  use ExUnit.Case

  alias Jeff.Command

  test "build commands no data payload" do
    assert %Command{address: 0x01, code: 0x60, name: POLL, data: nil} = Command.new(0x01, POLL)
    assert %Command{address: 0x01, code: 0x64, name: LSTAT, data: nil} = Command.new(0x01, LSTAT)
    assert %Command{address: 0x01, code: 0x65, name: ISTAT, data: nil} = Command.new(0x01, ISTAT)
    assert %Command{address: 0x01, code: 0x66, name: OSTAT, data: nil} = Command.new(0x01, OSTAT)
    assert %Command{address: 0x01, code: 0x67, name: RSTAT, data: nil} = Command.new(0x01, RSTAT)
  end

  test "build a new ID command" do
    assert %Command{address: 0x01, code: 0x61, name: ID, data: <<0x00>>} = Command.new(0x01, ID)
  end

  test "build a new CAP command" do
    assert %Command{address: 0x01, code: 0x62, name: CAP, data: <<0x00>>} = Command.new(0x01, CAP)
  end
end

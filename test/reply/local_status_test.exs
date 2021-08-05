defmodule Jeff.ReplyLocalStatusTest do
  use ExUnit.Case

  alias Jeff.Reply.LocalStatus

  test "decode local status report" do
    assert LocalStatus.decode(<<0x00, 0x00>>) ==
             %LocalStatus{tamper: :normal, power: :normal}

    assert LocalStatus.decode(<<0x01, 0x01>>) ==
             %LocalStatus{tamper: :tamper, power: :failure}
  end
end

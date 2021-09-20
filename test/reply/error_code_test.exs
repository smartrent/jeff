defmodule ReplyErrorCodeTest do
  use ExUnit.Case

  alias Jeff.Reply.ErrorCode

  test "new" do
    assert ErrorCode.new(0x00) ==
             %ErrorCode{code: 0x00, description: "No error"}
  end

  test "decode" do
    assert ErrorCode.decode(<<0x00>>) ==
             %ErrorCode{code: 0x00, description: "No error"}
  end
end

defmodule Jeff.Reply.InputStatusTest do
  use ExUnit.Case

  alias Jeff.Reply.InputStatus

  test "decode input status report" do
    assert InputStatus.decode(<<0x01>>) ==
             %InputStatus{
               inputs: %{
                 0 => :active
               }
             }

    assert InputStatus.decode(<<0x01, 0xFF, 0x00, 0xAB, 0x00>>) ==
             %InputStatus{
               inputs: %{
                 0 => :active,
                 1 => 0xFF,
                 2 => :inactive,
                 3 => 0xAB,
                 4 => :inactive
               }
             }
  end
end

defmodule Jeff.Reply.InputStatusTest do
  use ExUnit.Case

  alias Jeff.Reply.InputStatus

  test "decode input status report" do
    assert InputStatus.decode(<<1>>) ==
             %InputStatus{
               inputs: %{
                 0 => :active
               }
             }

    assert InputStatus.decode(<<0, 1, 0, 1, 0>>) ==
             %InputStatus{
               inputs: %{
                 0 => :inactive,
                 1 => :active,
                 2 => :inactive,
                 3 => :active,
                 4 => :inactive
               }
             }
  end
end

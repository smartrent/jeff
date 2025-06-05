defmodule Jeff.Reply.OutputStatusTest do
  use ExUnit.Case

  alias Jeff.Reply.OutputStatus

  test "decode input status report" do
    assert OutputStatus.decode(<<1>>) ==
             %OutputStatus{
               outputs: %{
                 0 => :active
               }
             }

    assert OutputStatus.decode(<<0, 1, 0, 1, 0>>) ==
             %OutputStatus{
               outputs: %{
                 0 => :inactive,
                 1 => :active,
                 2 => :inactive,
                 3 => :active,
                 4 => :inactive
               }
             }
  end
end

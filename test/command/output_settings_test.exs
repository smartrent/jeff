defmodule CommandOutputSettingsTest do
  use ExUnit.Case

  alias Jeff.Command.OutputSettings

  test "encode" do
    [output, code, timer] = [0x01, 0x00, 2]

    assert OutputSettings.encode(output: output, code: code, timer: timer) ==
             <<0x01, 0x00, 0x02, 0x00>>
  end
end

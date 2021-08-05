defmodule CommandBuzzerSettingsTest do
  use ExUnit.Case

  alias Jeff.Command.BuzzerSettings

  test "encode" do
    assert BuzzerSettings.encode([]) == <<0x00, 0x01, 0x00, 0x00, 0x00>>

    params = [
      reader: 0x01,
      tone: 0x02,
      on_time: 0x04,
      off_time: 0x08,
      count: 0x01
    ]

    assert BuzzerSettings.encode(params) == <<0x01, 0x02, 0x04, 0x08, 0x01>>
  end
end

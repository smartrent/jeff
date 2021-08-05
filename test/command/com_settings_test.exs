defmodule CommandComSettingsTest do
  use ExUnit.Case

  alias Jeff.Command.ComSettings

  test "encode" do
    assert ComSettings.encode([]) == <<0x00, 0x80, 0x25, 0x00, 0x00>>

    params = [
      address: 0x01,
      baud: 38400
    ]

    assert ComSettings.encode(params) ==
             <<0x01, 0x00, 0x96, 0x00, 0x00>>
  end
end

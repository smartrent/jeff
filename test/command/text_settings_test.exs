defmodule CommandTextSettingsTest do
  use ExUnit.Case

  alias Jeff.Command.TextSettings

  test "encode" do
    assert TextSettings.encode([]) == <<0x00, 0x01, 0x00, 0x00, 0x00, 0x00>>

    params = [
      reader: 0x01,
      temporary?: true,
      wrap?: true,
      time: 0x04,
      row: 0x01,
      column: 0x02,
      content: "Jeff"
    ]

    assert TextSettings.encode(params) ==
             <<0x01, 0x03, 0x04, 0x01, 0x02, 0x04, "Jeff">>
  end
end

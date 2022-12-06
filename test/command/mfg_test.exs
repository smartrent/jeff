defmodule Jeff.Command.MfgTest do
  use ExUnit.Case

  alias Jeff.Command.Mfg

  test "encode vendor code as little-endian" do
    <<vendor_code::24, data::binary>> =
      Mfg.encode(
        vendor_code: 0xC0FFEE,
        data: <<0x01::8, 0x02::8, 0x0304::16, 0x050607::24>>
      )

    assert 0xEEFFC0 = vendor_code
    assert <<0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07>> = data
  end
end

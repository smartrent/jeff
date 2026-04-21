defmodule ControlInfoTest do
  use ExUnit.Case

  import Jeff.ControlInfo, only: [encode: 3, decode: 1]

  defmacro assert_byte(actual, expected) do
    quote do
      format_binary = fn i ->
        "0b" <> (i |> Integer.to_string(2) |> String.pad_leading(8, "0"))
      end

      actual = unquote(actual) |> format_binary.()
      expected = unquote(expected) |> format_binary.()

      assert actual == expected
    end
  end

  test "builds default message control info byte" do
    assert_byte(encode(0, :checksum, false), 0b00000000)
    assert_byte(encode(1, :checksum, false), 0b00000001)
    assert_byte(encode(2, :checksum, false), 0b00000010)
    assert_byte(encode(3, :checksum, false), 0b00000011)
    assert_byte(encode(0, :crc, false), 0b00000100)
    assert_byte(encode(0, :checksum, true), 0b00001000)
  end

  test "builds default message control info from byte" do
    assert decode(0b00000000) == {0, :checksum, false}
    assert decode(0b00000001) == {1, :checksum, false}
    assert decode(0b00000010) == {2, :checksum, false}
    assert decode(0b00000011) == {3, :checksum, false}
    assert decode(0b00000100) == {0, :crc, false}
    assert decode(0b00001000) == {0, :checksum, true}
  end

  test "ignores reserved bits in control info byte" do
    # 0x53 (the OSDP SOM byte) has non-zero reserved bits but valid lower bits;
    # a misbehaving peripheral can send this as a control byte and must not crash.
    # 0x53 = 0b01010011 → reserved=0101, security?=0, check=0 (checksum), seq=3
    assert decode(0x53) == {3, :checksum, false}
    # reserved bits all set, lower nibble all zero
    assert decode(0b11110000) == {0, :checksum, false}
    # reserved bits set, crc, no security, seq=1
    assert decode(0b10100101) == {1, :crc, false}
  end
end

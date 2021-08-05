defmodule ControlInfoTest do
  use ExUnit.Case

  import Jeff.ControlInfo, only: [new: 0, new: 1, from_byte: 1]

  defmacro assert_byte(actual, expected) do
    quote do
      actual = unquote(actual) |> maybe_get_byte() |> format_binary()
      expected = unquote(expected) |> maybe_get_byte() |> format_binary()

      assert actual == expected
    end
  end

  def maybe_get_byte(%{byte: byte}), do: byte
  def maybe_get_byte(byte), do: byte

  defp format_binary(i) do
    "0b" <> (i |> Integer.to_string(2) |> String.pad_leading(8, "0"))
  end

  test "builds default message control info byte" do
    assert_byte(new(), 0b00000000)
    assert_byte(new(sequence_number: 1), 0b00000001)
    assert_byte(new(sequence_number: 2), 0b00000010)
    assert_byte(new(sequence_number: 3), 0b00000011)
    assert_byte(new(check_scheme: :crc), 0b00000100)
    assert_byte(new(security_control_block?: true), 0b00001000)
  end

  test "builds default message control info from byte" do
    assert_byte(from_byte(0b00000000), new())
    assert_byte(from_byte(0b00000001), new(sequence_number: 1))
    assert_byte(from_byte(0b00000010), new(sequence_number: 2))
    assert_byte(from_byte(0b00000011), new(sequence_number: 3))
    assert_byte(from_byte(0b00000100), new(check_scheme: :crc))
    assert_byte(from_byte(0b00001000), new(security_control_block?: true))
  end
end

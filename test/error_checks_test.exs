defmodule ErrorChecksTest do
  use ExUnit.Case

  import Jeff.ErrorChecks

  @doc """
  Example 1:
  537F0D00046E00802500006E38
  6E38 is the CRC here (in Little endian format)
  Example 2:
  53000900046100C066
  C066 is the CRC here (in Little endian format)
  """
  test "generates crc for binary data" do
    data = "537F0D00046E0080250000" |> Base.decode16!()
    check = "6E38" |> Base.decode16!() |> :binary.decode_unsigned(:little)
    assert crc(data) == check

    data = "53000900046100" |> Base.decode16!()
    check = "C066" |> Base.decode16!() |> :binary.decode_unsigned(:little)
    assert crc(data) == check
  end

  @doc """
  Example 1 :
  537F0C00006E00802500000F
  0F is the Checksum here
  Example 2:
  5300080000610044
  44 is the Checksum here
  """
  test "generates checksum for binary data" do
    data = "537F0C00006E0080250000" |> Base.decode16!()
    check = "0F" |> Base.decode16!() |> :binary.decode_unsigned(:little)
    assert checksum(data) == check

    data = "53000800006100" |> Base.decode16!()
    check = "44" |> Base.decode16!() |> :binary.decode_unsigned(:little)
    assert checksum(data) == check
  end
end

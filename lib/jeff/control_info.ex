defmodule Jeff.ControlInfo do
  @moduledoc false

  def encode(%{sequence: seq, check_scheme: cs, security?: sec}) do
    encode(seq, cs, sec)
  end

  def encode(sequence, check_scheme, security?) do
    check_scheme =
      case check_scheme do
        :checksum -> 0
        :crc -> 1
      end

    security? =
      case security? do
        false -> 0
        true -> 1
      end

    <<byte>> = <<
      0::size(4),
      security?::size(1),
      check_scheme::size(1),
      sequence::size(2)
    >>

    byte
  end

  def decode(<<byte>>), do: decode(byte)

  def decode(byte) when is_integer(byte) do
    <<
      0::size(4),
      security?::size(1),
      check_scheme::size(1),
      sequence::size(2)
    >> = <<byte>>

    check_scheme =
      case check_scheme do
        0 -> :checksum
        1 -> :crc
      end

    security? =
      case security? do
        0 -> false
        1 -> true
      end

    {sequence, check_scheme, security?}
  end
end

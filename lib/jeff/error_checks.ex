defmodule Jeff.ErrorChecks do
  use Bitwise

  @spec crc(binary()) :: integer()
  def crc(data) when is_binary(data) do
    crc_defn = :cerlc.init(:crc16_aug_ccitt)
    :cerlc.calc_crc(data, crc_defn)
  end

  @spec checksum(binary()) :: integer()
  def checksum(data) when is_binary(data) do
    <<i <- data>>
    |> for(do: i)
    |> Enum.sum()
    |> band(0xFF)
    |> Kernel.-(256)
    |> Kernel.-()
  end
end

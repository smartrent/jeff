defmodule Jeff.ControlInfo do
  defstruct sequence_number: 0,
            check_scheme: :checksum,
            security_control_block?: false,
            byte: nil

  @spec new(keyword()) :: %__MODULE__{}
  def new(options \\ []) do
    struct(__MODULE__, options) |> build()
  end

  defp build(
         %{
           sequence_number: sequence_number,
           check_scheme: check_scheme,
           security_control_block?: security_control_block
         } = info
       ) do
    check_scheme =
      case check_scheme do
        :checksum -> 0
        :crc -> 1
      end

    security_control_block =
      case security_control_block do
        false -> 0
        true -> 1
      end

    <<byte>> = <<
      0::size(4),
      security_control_block::size(1),
      check_scheme::size(1),
      sequence_number::size(2)
    >>

    %{info | byte: byte}
  end

  @spec from_byte(binary()) :: %__MODULE__{}
  def from_byte(<<byte>>), do: from_byte(byte)

  @spec from_byte(integer()) :: %__MODULE__{}
  def from_byte(byte) when is_integer(byte) do
    <<
      0::size(4),
      security_control_block::size(1),
      check_scheme::size(1),
      sequence_number::size(2)
    >> = <<byte>>

    check_scheme =
      case check_scheme do
        0 -> :checksum
        1 -> :crc
      end

    security_control_block =
      case security_control_block do
        0 -> false
        1 -> true
      end

    new(
      sequence_number: sequence_number,
      check_scheme: check_scheme,
      security_control_block?: security_control_block
    )
  end
end

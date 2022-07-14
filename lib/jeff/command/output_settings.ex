defmodule Jeff.Command.OutputSettings do
  @moduledoc """
  Output control command

  OSDP v2.2 Specification Reference: 6.7

  Control Code Values

  | Code | Description                                                       |
  |------|-------------------------------------------------------------------|
  | 0x00 | NOP – do not alter this output                                    |
  | 0x01 | Set the permanent state to OFF, abort timed operation (if any)    |
  | 0x02 | Set the permanent state to ON, abort timed operation (if any)     |
  | 0x03 | Set the permanent state to OFF, allow timed operation to complete |
  | 0x04 | Set the permanent state to ON, allow timed operation to complete  |
  | 0x05 | Set the temporary state to ON, resume permanent state on timeout  |
  | 0x06 | Set the temporary state to OFF, resume permanent state on timeout |
  """

  @spec encode(output: pos_integer(), code: pos_integer(), timer: pos_integer()) :: <<_::32>>
  def encode(output: output, code: code, timer: timer) do
    <<output, code, timer::size(2)-unit(8)-little>>
  end
end

defmodule Jeff.Reply.ComData do
  @moduledoc """
  Communication Configuration Report

  OSDP v2.2 Specification Reference: 7.13
  """

  defstruct address: 0x00,
            baud: 9600

  @type t :: %__MODULE__{
          address: Jeff.osdp_address(),
          baud: 9600
        }

  @spec decode(binary()) :: t()
  def decode(<<address, baud::size(4)-unit(8)-little>>) do
    %__MODULE__{address: address, baud: baud}
  end
end

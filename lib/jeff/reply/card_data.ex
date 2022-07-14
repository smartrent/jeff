defmodule Jeff.Reply.CardData do
  @moduledoc """
  Card Data Report

  OSDP v2.2 Specification Reference: 7.10
  """

  defstruct [:reader, :format, :length, :data]

  @type t :: %__MODULE__{
          reader: byte(),
          format: byte(),
          length: pos_integer(),
          data: binary()
        }

  @spec decode(<<_::40>>) :: t()
  def decode(<<reader, format, length::size(16)-little, data::binary>>) do
    %__MODULE__{
      reader: reader,
      format: format,
      length: length,
      data: data
    }
  end
end

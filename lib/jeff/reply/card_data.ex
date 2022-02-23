defmodule Jeff.Reply.CardData do
  @moduledoc """
  Card Data Report

  OSDP v2.2 Specification Reference: 7.10
  """

  defstruct [:reader, :format, :length, :data]

  def decode(<<reader, format, length::size(16)-little, data::binary>>) do
    %__MODULE__{
      reader: reader,
      format: format,
      length: length,
      data: data
    }
  end
end

defmodule Jeff.Reply.CardData do
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

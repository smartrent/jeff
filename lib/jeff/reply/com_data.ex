defmodule Jeff.Reply.ComData do
  defstruct address: 0x00,
            baud: 9600

  def decode(<<address, baud::size(4)-unit(8)-little>>) do
    %__MODULE__{address: address, baud: baud}
  end
end

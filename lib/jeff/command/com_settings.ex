defmodule Jeff.Command.ComSettings do
  defstruct address: 0x00,
            baud: 9600

  def new(params \\ []) do
    struct(__MODULE__, params)
  end

  def encode(params) do
    %{address: address, baud: baud} = new(params)
    <<address, baud::size(4)-unit(8)-little>>
  end
end

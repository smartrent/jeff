defmodule Jeff.Reply.KeypadData do
  defstruct [:reader, :count, :keys]

  def decode(<<reader, count, keys::binary>>) do
    %__MODULE__{reader: reader, count: count, keys: keys}
  end
end

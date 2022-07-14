defmodule Jeff.Reply.KeypadData do
  @moduledoc """
  Keypad Data Report

  OSDP v2.2 Specification Reference: 7.12
  """

  defstruct [:reader, :count, :keys]

  @type t :: %__MODULE__{
          reader: byte(),
          count: pos_integer(),
          keys: binary()
        }

  @spec decode(binary()) :: t()
  def decode(<<reader, count, keys::binary>>) do
    %__MODULE__{reader: reader, count: count, keys: keys}
  end
end

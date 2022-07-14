defmodule Jeff.Command.EncryptionServer do
  @moduledoc false
  @spec encode(cryptogram: binary()) :: binary()
  def encode(cryptogram: cryptogram), do: cryptogram
end

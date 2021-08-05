defmodule Jeff.Command.EncryptionKey do
  @secure_channel_base_key 0x01

  defstruct [:key, type: @secure_channel_base_key]

  def new(key: key) do
    %__MODULE__{key: key}
  end

  def encode(params) do
    %{key: key, type: type} = new(params)
    <<type, key_length(key)>> <> key
  end

  defp key_length(key) do
    div(bit_size(key) + 7, 8)
  end
end

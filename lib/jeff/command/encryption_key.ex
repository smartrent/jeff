defmodule Jeff.Command.EncryptionKey do
  @moduledoc false

  @secure_channel_base_key 0x01

  defstruct [:key, type: @secure_channel_base_key]

  @type t :: %__MODULE__{key: binary(), type: 0x01}

  @spec new(key: binary()) :: t()
  def new(key: key) do
    %__MODULE__{key: key}
  end

  @spec encode(key: binary()) :: <<_::24>>
  def encode(params) do
    %{key: key, type: type} = new(params)
    <<type, key_length(key)>> <> key
  end

  defp key_length(key) do
    div(bit_size(key) + 7, 8)
  end
end

defmodule Jeff.Reply.MfgReply do
  @moduledoc """
  Manufacturer-specific reply
  """

  defstruct [:vendor_code, :data]

  @type param :: {:vendor_code, Jeff.vendor_code()} | {:data, binary()}

  @type t :: %__MODULE__{
          vendor_code: Jeff.vendor_code(),
          data: binary()
        }

  @spec new(keyword()) :: t()
  def new(params \\ []), do: struct(__MODULE__, params)

  @spec decode(<<_::24, _::_*8>>) :: t()
  def decode(<<vendor_code::little-size(24), data::binary>>),
    do: %__MODULE__{vendor_code: vendor_code, data: data}
end

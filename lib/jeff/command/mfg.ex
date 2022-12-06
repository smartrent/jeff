defmodule Jeff.Command.Mfg do
  @moduledoc """
  Manufacturer-specific command

  OSDP v2.2 Specification Reference: 6.19
  """

  defstruct [:vendor_code, :data]

  @type param :: {:vendor_code, Jeff.vendor_code()} | {:data, binary()}

  @type t :: %__MODULE__{
          vendor_code: Jeff.vendor_code(),
          data: binary()
        }

  @spec new([param()]) :: t()
  def new(params \\ []), do: struct(__MODULE__, params)

  @spec encode([param()]) :: <<_::24, _::_*8>>
  def encode(params) when is_list(params), do: params |> new() |> encode()

  @spec encode(t()) :: <<_::24, _::_*8>>
  def encode(%__MODULE__{vendor_code: vendor_code, data: data}),
    do: <<vendor_code::little-size(24), data::binary>>
end

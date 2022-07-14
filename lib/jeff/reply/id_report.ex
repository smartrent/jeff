defmodule Jeff.Reply.IdReport do
  @moduledoc """
  Device identification Report

  OSDP v2.2 Specification Reference: 7.4
  """

  defstruct [:vendor, :model, :version, :serial, :firmware]

  @type t :: %__MODULE__{
          firmware: String.t(),
          model: integer(),
          serial: String.t(),
          vendor: String.t(),
          version: integer()
        }

  def decode(data) do
    <<
      vendor1,
      vendor2,
      vendor3,
      model,
      version,
      serial::size(32),
      fw_major,
      fw_minor,
      fw_build
    >> = data

    vendor = [vendor1, vendor2, vendor3] |> Enum.map_join(&hex/1)
    serial = hex(serial) |> String.pad_leading(8, "0")
    firmware = "#{fw_major}.#{fw_minor}.#{fw_build}"

    %__MODULE__{
      vendor: vendor,
      model: model,
      version: version,
      serial: serial,
      firmware: firmware
    }
  end

  defp hex(i), do: Integer.to_string(i, 16)
end

defmodule Jeff.Reply.IdReport do
  defstruct [:vendor, :model, :version, :serial, :firmware]

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

    vendor = [vendor1, vendor2, vendor3] |> Enum.map(&hex/1) |> Enum.join()
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

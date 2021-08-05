defmodule Jeff.Reply.LocalStatus do
  defstruct [:tamper, :power]

  def new(tamper_code, power_code) do
    %__MODULE__{
      tamper: tamper_status(tamper_code),
      power: power_status(power_code)
    }
  end

  def decode(<<tamper, power>>) do
    __MODULE__.new(tamper, power)
  end

  defp tamper_status(0x00), do: :normal
  defp tamper_status(0x01), do: :tamper

  defp power_status(0x00), do: :normal
  defp power_status(0x01), do: :failure
end

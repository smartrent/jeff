defmodule Jeff.Reply.LocalStatus do
  @moduledoc """
  Local Status Report

  OSDP v2.2 Specification Reference: 7.6
  """

  defstruct [:tamper, :power]

  @type tamper_status() :: :normal | :tamper
  @type power_status() :: :normal | :failure
  @type tamper_code() :: 0x00 | 0x01
  @type power_code() :: 0x00 | 0x01

  @type t :: %__MODULE__{
          tamper: tamper_status(),
          power: power_status()
        }

  @spec new(tamper_code(), power_code()) :: t()
  def new(tamper_code, power_code) do
    %__MODULE__{
      tamper: tamper_status(tamper_code),
      power: power_status(power_code)
    }
  end

  @spec decode(binary()) :: t()
  def decode(<<tamper, power>>) do
    __MODULE__.new(tamper, power)
  end

  defp tamper_status(0x00), do: :normal
  defp tamper_status(0x01), do: :tamper

  defp power_status(0x00), do: :normal
  defp power_status(0x01), do: :failure
end

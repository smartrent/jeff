defmodule Jeff.Reply.Capability do
  @moduledoc """
  Peripheral Device Capabilities Report

  OSDP v2.2 Specification Reference: 7.5
  """

  defstruct [:function, :compliance, :number_of, :description]

  @type t :: %__MODULE__{
          function: integer(),
          compliance: integer(),
          number_of: integer(),
          description: String.t()
        }

  @functions %{
    1 => "Contact Status Monitoring",
    2 => "Output Control",
    3 => "Card Data Format",
    4 => "Reader LED Control",
    5 => "Reader Audible Output",
    6 => "Reader Text Output",
    7 => "Time Keeping",
    8 => "Check Character Support",
    9 => "Communication Security",
    10 => "Receive BufferSize",
    11 => "Largest Combined Message Size",
    12 => "Smart Card Support",
    13 => "Readers",
    14 => "Biometrics",
    15 => "Secure PIN Entry Support",
    16 => "OSDP Version"
  }

  def new(function, compliance, number_of) do
    %__MODULE__{
      function: function,
      compliance: compliance,
      number_of: number_of,
      description: @functions[function]
    }
  end

  @spec decode(binary()) :: [t()]
  def decode(data) do
    do_decode(data, [])
  end

  defp do_decode(<<function, compliance, number_of, rest::binary>>, capabilities) do
    capability = __MODULE__.new(function, compliance, number_of)
    do_decode(rest, [capability | capabilities])
  end

  defp do_decode(<<>>, capabilities) do
    capabilities |> Enum.reverse()
  end
end

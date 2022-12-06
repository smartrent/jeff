defprotocol Jeff.MfgCommand do
  @moduledoc """
  The `Jeff.MfgCommand` protocol converts an Elixir data structure into an
  osdp_MFG command.

  ### Example

      defmodule InputDisable do
        defstruct input_number: nil, duration: nil

        defimpl Jeff.MfgCommand do
          def vendor_code(_), do: 0xC0FFEE

          def encode(command) do
            <<command.input_number::8, duration::16>>
          end
        end
      end

      Jeff.send_command(acu, address, %InputDisable{input_number: 1, duration: 5000})
  """

  @doc """
  Returns the 3-byte vendor code associated with the command.
  """
  @spec vendor_code(t()) :: Jeff.vendor_code()
  def vendor_code(command)

  @doc """
  Encodes the given `command` as a binary.
  """
  @spec encode(t) :: Jeff.Command.Mfg.t()
  def encode(command)
end

defmodule Jeff.Reply.ErrorCode do
  defstruct [:code, :description]

  @description %{
    0x00 => "No error",
    0x01 => "Message check character(s) error (bad cksum/crc)",
    0x02 => "Command length error",
    0x03 => "Unknown Command Code - Command not implemented by PD",
    0x04 => "Unexpected sequence number detected in the header",
    0x05 => "This PD does not support the security block that was received",
    0x06 => "Encrypted communication is required to process this command",
    0x07 => "BIO_TYPE not supported",
    0x08 => "BIO_FORMAT not supported",
    0x09 => "Unable to process command record"
  }

  def new(code) do
    %__MODULE__{code: code, description: description(code)}
  end

  def decode(<<code>>), do: new(code)

  defp description(code), do: @description[code]
end

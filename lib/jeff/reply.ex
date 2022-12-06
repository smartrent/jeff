defmodule Jeff.Reply do
  @moduledoc """
  Replies are sent from a PD to an ACU in response to a command

  | Name      | Code | Description                                | Data Type        |
  |-----------|------|--------------------------------------------|------------------|
  | ACK       | 0x40 | Command accepted, nothing else to report   | -                |
  | NAK       | 0x41 | Command not processed                      | ErrorCode        |
  | PDID      | 0x45 | PD ID Report                               | IdReport         |
  | PDCAP     | 0x46 | PD Capabilities Report                     | [Capability]     |
  | LSTATR    | 0x48 | Local Status Report                        | Report data      |
  | ISTATR    | 0x49 | Input Status Report                        | Report data      |
  | OSTATR    | 0x4A | Output Status Report                       | Report data      |
  | RSTATR    | 0x4B | Reader Status Report                       | Report data      |
  | RAW       | 0x50 | Reader Data – Raw bit image of card data   | CardData         |
  | FMT       | 0x51 | Reader Data – Formatted character stream   | CardData         |
  | KEYPAD    | 0x53 | Keypad Data                                | KeypadData       |
  | COM       | 0x54 | PD Communications Configuration Report     | ComData          |
  | BIOREADR  | 0x57 | Biometric Data                             | Biometric data   |
  | BIOMATCHR | 0x58 | Biometric Match Result                     | Result           |
  | CCRYPT    | 0x76 | Client's ID, Random Number, and Cryptogram | EncryptionClient |
  | BUSY      | 0x79 | PD is Busy reply                           | -                |
  | RMAC_I    | 0x78 | Initial R-MAC                              | Encryption Data  |
  | FTSTAT    | 0x7A | File transfer status                       | Status details   |
  | PIVDATAR  | 0x80 | PIV Data Reply                             | credential data  |
  | GENAUTHR  | 0x81 | Authentication response                    | response details |
  | CRAUTHR   | 0x82 | Response to challenge                      | response details |
  | MFGSTATR  | 0x83 | MFG specific status                        | status details   |
  | MFGERRR   | 0x84 | MFG specific error                         | error details    |
  | MFGREP    | 0x90 | Manufacturer Specific Reply                | Any              |
  | XRD       | 0xB1 | Extended Read Response                     | APDU and details |
  """

  import Bitwise

  alias Jeff.Reply.{
    Capabilities,
    CardData,
    ComData,
    EncryptionClient,
    ErrorCode,
    IdReport,
    InputStatus,
    KeypadData,
    LocalStatus,
    MfgReply,
    OutputStatus
  }

  @type t() :: %__MODULE__{
          address: byte(),
          code: byte(),
          data: any(),
          name: atom()
        }

  defstruct [:address, :code, :data, :name]

  @names %{
    0x40 => ACK,
    0x41 => NAK,
    0x45 => PDID,
    0x46 => PDCAP,
    0x48 => LSTATR,
    0x49 => ISTATR,
    0x4A => OSTATR,
    0x4B => RSTATR,
    0x50 => RAW,
    0x51 => FMT,
    0x53 => KEYPAD,
    0x54 => COM,
    0x57 => BIOREADR,
    0x58 => BIOMATCHR,
    0x76 => CCRYPT,
    0x79 => BUSY,
    0x78 => RMAC_I,
    0x7A => FTSTAT,
    0x80 => PIVDATAR,
    0x81 => GENAUTHR,
    0x82 => CRAUTHR,
    0x83 => MFGSTATR,
    0x84 => MFGERRR,
    0x90 => MFGREP,
    0xB1 => XRD
  }
  @codes Map.new(@names, fn {code, name} -> {name, code} end)

  @type name :: unquote(Enum.reduce(Map.values(@names), &{:|, [], [&1, &2]}))
  @type code :: unquote(Enum.reduce(Map.keys(@names), &{:|, [], [&1, &2]}))

  @spec new(Jeff.Message.t()) :: t()
  def new(%{code: code, data: data, address: address}) do
    name_or_code = Map.get(@names, code, code)
    new(address, name_or_code, data)
  end

  @spec new(pos_integer(), name() | code(), binary() | nil) :: t()
  def new(address, code, data \\ nil)

  def new(address, code, data) when is_integer(code) do
    %__MODULE__{
      address: reply_mask(address),
      code: code,
      data: data,
      name: UNKNOWN
    }
  end

  def new(address, name, data) do
    %__MODULE__{
      address: reply_mask(address),
      code: code(name),
      data: decode(name, data),
      name: name
    }
  end

  defp reply_mask(address) do
    address &&& 0b01111111
  end

  defp decode(ACK, _data), do: Jeff.Reply.ACK
  defp decode(NAK, data), do: ErrorCode.decode(data)
  defp decode(PDID, data), do: IdReport.decode(data)
  defp decode(PDCAP, data), do: Capabilities.decode(data)
  defp decode(LSTATR, data), do: LocalStatus.decode(data)
  defp decode(ISTATR, data), do: InputStatus.decode(data)
  defp decode(OSTATR, data), do: OutputStatus.decode(data)
  defp decode(COM, data), do: ComData.decode(data)
  defp decode(KEYPAD, data), do: KeypadData.decode(data)
  defp decode(RAW, data), do: CardData.decode(data)
  defp decode(CCRYPT, data), do: EncryptionClient.decode(data)
  defp decode(MFGREP, data), do: MfgReply.decode(data)
  defp decode(RMAC_I, data), do: data
  defp decode(_name, nil), do: nil
  defp decode(_name, <<>>), do: nil
  defp decode(name, data), do: Module.concat(__MODULE__, name).decode(data)

  @spec code(name()) :: code()
  def code(name), do: @codes[name]
  @spec name(code()) :: name()
  def name(code), do: @names[code]
end

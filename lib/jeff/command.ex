defmodule Jeff.Command do
  @moduledoc """
  Commands are sent from an ACU to a PD

  | Code | Name         | Description                           | Data Type               |
  |------|--------------|---------------------------------------|-------------------------|
  | 0x60 | POLL         | Poll                                  | -                       |
  | 0x61 | ID           | ID Report Request                     | -                       |
  | 0x62 | CAP          | PD Capabilities Request               | [Capability]            |
  | 0x64 | LSTAT        | Local Status Report Request           | -                       |
  | 0x65 | ISTAT        | Input Status Report Request           | -                       |
  | 0x66 | OSTAT        | Output Status Report Request          | -                       |
  | 0x67 | RSTAT        | Reader Status Report Request          | -                       |
  | 0x68 | OUT          | Output Control Command                | OutputSettings          |
  | 0x69 | LED          | Reader Led Control Command            | LedSettings             |
  | 0x6A | BUZ          | Reader Buzzer Control Command         | BuzzerSettings          |
  | 0x6B | TEXT         | Text Output Command                   | TextSettings            |
  | 0x6E | COMSET       | PD Communication Config Command       | ComSettings             |
  | 0x73 | BIOREAD      | Scan and Send Biometric Data          | Requested Return Format |
  | 0x74 | BIOMATCH     | Scan and Match Biometric Template     | Biometric Template      |
  | 0x75 | KEYSET       | Encryption Key Set Command            | EncryptionKey           |
  | 0x76 | CHLNG        | Challenge/Secure Session Init Request | ChallengeData           |
  | 0x77 | SCRYPT       | Server Cryptogram                     | EncryptionData          |
  | 0x7B | ACURXSIZE    | Max ACU receive size                  | Buffer size             |
  | 0x7C | FILETRANSFER | Send data file to PD                  | File contents           |
  | 0x80 | MFG          | Manufacturer Specific Command         | Any                     |
  | 0xA1 | XWR          | Extended write data                   | APDU and details        |
  | 0xA2 | ABORT        | Abort PD operation                    | -                       |
  | 0xA3 | PIVDATA      | Get PIV Data                          | Object details          |
  | 0xA4 | GENAUTH      | Request Authenticate                  | Request details         |
  | 0xA5 | CRAUTH       | Request Crypto Response               | Challenge details       |
  | 0xA7 | KEEPACTIVE   | PD read activation                    | Time duration           |
  """

  @type t() :: %__MODULE__{
          address: byte(),
          code: byte(),
          data: binary(),
          name: name(),
          caller: reference()
        }

  defstruct [:address, :code, :data, :name, :caller]

  alias Jeff.Command.{
    BuzzerSettings,
    ChallengeData,
    ComSettings,
    EncryptionKey,
    EncryptionServer,
    LedSettings,
    OutputSettings,
    TextSettings
  }

  @names %{
    0x60 => POLL,
    0x61 => ID,
    0x62 => CAP,
    0x64 => LSTAT,
    0x65 => ISTAT,
    0x66 => OSTAT,
    0x67 => RSTAT,
    0x68 => OUT,
    0x69 => LED,
    0x6A => BUZ,
    0x6B => TEXT,
    0x6E => COMSET,
    0x73 => BIOREAD,
    0x74 => BIOMATCH,
    0x75 => KEYSET,
    0x76 => CHLNG,
    0x77 => SCRYPT,
    0x7B => ACURXSIZE,
    0x7C => FILETRANSFER,
    0x80 => MFG,
    0xA1 => XWR,
    0xA2 => ABORT,
    0xA3 => PIVDATA,
    0xA4 => GENAUTH,
    0xA5 => CRAUTH,
    0xA7 => KEEPACTIVE
  }
  @codes Map.new(@names, fn {code, name} -> {name, code} end)

  @type name :: unquote(Enum.reduce(Map.values(@names), &{:|, [], [&1, &2]}))
  @type code :: unquote(Enum.reduce(Map.keys(@names), &{:|, [], [&1, &2]}))

  @spec new(Jeff.osdp_address(), name(), keyword()) :: t()
  def new(address, name, params \\ []) do
    {caller, params} = Keyword.pop(params, :caller)

    code = code(name)
    data = encode(name, params)

    %__MODULE__{
      address: address,
      code: code,
      data: data,
      name: name,
      caller: caller
    }
  end

  defp encode(POLL, _params), do: nil
  defp encode(ID, _params), do: <<0x00>>
  defp encode(CAP, _params), do: <<0x00>>
  defp encode(LSTAT, _params), do: nil
  defp encode(ISTAT, _params), do: nil
  defp encode(OSTAT, _params), do: nil
  defp encode(RSTAT, _params), do: nil
  defp encode(OUT, params), do: OutputSettings.encode(params)
  defp encode(LED, params), do: LedSettings.encode(params)
  defp encode(BUZ, params), do: BuzzerSettings.encode(params)
  defp encode(TEXT, params), do: TextSettings.encode(params)
  defp encode(COMSET, params), do: ComSettings.encode(params)
  defp encode(KEYSET, params), do: EncryptionKey.encode(params)
  defp encode(CHLNG, params), do: ChallengeData.encode(params)
  defp encode(SCRYPT, params), do: EncryptionServer.encode(params)
  defp encode(ACURXSIZE, size: size), do: <<size::size(16)-little>>
  defp encode(ABORT, _params), do: nil

  @spec code(name()) :: code()
  def code(name), do: @codes[name]
  @spec name(code()) :: name()
  def name(code), do: @names[code]
end

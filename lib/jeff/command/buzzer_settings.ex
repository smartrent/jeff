defmodule Jeff.Command.BuzzerSettings do
  @moduledoc """
  Reader Buzzer Control Command

  OSDP v2.2 Specification Reference: 6.11
  """

  defstruct reader: 0x00,
            tone: 0x01,
            on_time: 0x00,
            off_time: 0x00,
            count: 0x00

  @typedoc """
  Requested tone state

  0x00 = no tone (off) – use of this value is deprecated.
  0x01 = off
  0x02 = default tone
  0x03-0xff = Reserved for future use
  """
  @type tone_code() :: 0x00..0xFF

  @typedoc """
  The ON duration of the sound, in units of 100ms. Must be nonzero unless the
  tone code is 0x01 (off).
  """
  @type on_time() :: 0x00..0xFF

  @typedoc """
  The OFF duration of the sound, in units of 100ms.
  """
  @type off_time() :: 0x00..0xFF

  @typedoc """
  The number of times to repeat the ON/OFF cycle. 0 = tone continues until
  another tone command is received.
  """
  @type count() :: 0x00..0xFF

  @type t :: %__MODULE__{
          reader: integer(),
          tone: tone_code(),
          on_time: on_time(),
          off_time: off_time(),
          count: count()
        }

  @type param() ::
          {:reader, integer()}
          | {:tone, tone_code()}
          | {:on_time, on_time()}
          | {:off_time, off_time()}
          | {:count, count()}
  @type params :: t() | [param()]

  @spec new(params()) :: t()
  def new(params \\ []) do
    struct(__MODULE__, params)
  end

  @spec encode(params()) :: binary()
  def encode(params) do
    settings = new(params)

    <<
      settings.reader,
      settings.tone,
      settings.on_time,
      settings.off_time,
      settings.count
    >>
  end
end

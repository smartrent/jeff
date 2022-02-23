defmodule Jeff.Command.LedSettings do
  @moduledoc """
  Reader LED control command

  OSDP v2.2 Specification Reference: 6.10

  Temporary Control Code Values

  | Code | Description
  |------|----------------------------------------------------------------------------------------------------------------------|
  | 0x00 | NOP – do not alter this LED's temporary settings. The remaining values of the temporary settings record are ignored. |
  | 0x01 | Cancel any temporary operation and display this LED's permanent state immediately.                                   |
  | 0x02 | Set the temporary state as given and start timer immediately.                                                        |

  Permanent Control Code Values

  | Code | Description
  |-----------------------------------------------------------------------------------------------------------------------------|
  | 0x00 | NOP – do not alter this LED's permanent settings. The remaining values of the temporary settings record are ignored. |
  | 0x01 | Set the permanent state as given.                                                                                    |

  Color Values

  | Value | Description       |
  |---------------------------|
  | 0     | Black (off/unlit) |
  | 1     | Red               |
  | 2     | Green             |
  | 3     | Amber             |
  | 4     | Blue              |
  | 5     | Magenta           |
  | 6     | Cyan              |
  | 7     | White             |
  """

  defstruct reader: 0x0,
            led: 0x0,
            temp_mode: 0x00,
            temp_on_time: 0x00,
            temp_off_time: 0x00,
            temp_on_color: 0x00,
            temp_off_color: 0x00,
            temp_timer: 0x00,
            perm_mode: 0x00,
            perm_on_time: 0x00,
            perm_off_time: 0x00,
            perm_on_color: 0x00,
            perm_off_color: 0x00

  @type t :: %__MODULE__{
          reader: integer(),
          led: integer(),
          temp_mode: 0x00 | 0x01 | 0x02,
          temp_on_time: integer(),
          temp_off_time: integer(),
          temp_on_color: 0x00..0x07,
          temp_off_color: 0x00..0x07,
          temp_timer: integer(),
          perm_mode: 0x00 | 0x01,
          perm_on_time: integer(),
          perm_off_time: integer(),
          perm_on_color: 0x00..0x07,
          perm_off_color: 0x00..0x07
        }

  @type param() ::
          {:reader, integer()}
          | {:led, integer()}
          | {:temp_mode, 0x00 | 0x01 | 0x02}
          | {:temp_on_time, integer()}
          | {:temp_off_time, integer()}
          | {:temp_on_color, 0x00..0x07}
          | {:temp_off_color, 0x00..0x07}
          | {:temp_timer, integer()}
          | {:perm_mode, 0x00 | 0x01}
          | {:perm_on_time, integer()}
          | {:perm_off_time, integer()}
          | {:perm_on_color, 0x00..0x07}
          | {:perm_off_color, 0x00..0x07}
  @type params() :: t() | [param()]

  @spec new(params()) :: t()
  def new(params) do
    struct(__MODULE__, params)
  end

  @spec encode(params()) :: binary()
  def encode(params) do
    settings = new(params)

    <<
      settings.reader,
      settings.led,
      settings.temp_mode,
      settings.temp_on_time,
      settings.temp_off_time,
      settings.temp_on_color,
      settings.temp_off_color,
      settings.temp_timer::size(2)-unit(8)-little,
      settings.perm_mode,
      settings.perm_on_time,
      settings.perm_off_time,
      settings.perm_on_color,
      settings.perm_off_color
    >>
  end
end

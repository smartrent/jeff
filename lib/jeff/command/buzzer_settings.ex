defmodule Jeff.Command.BuzzerSettings do
  defstruct reader: 0x00,
            tone: 0x01,
            on_time: 0x00,
            off_time: 0x00,
            count: 0x00

  def new(params \\ []) do
    struct(__MODULE__, params)
  end

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

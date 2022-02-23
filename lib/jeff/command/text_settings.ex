defmodule Jeff.Command.TextSettings do
  @moduledoc false

  defstruct reader: 0x00,
            temporary?: false,
            wrap?: false,
            time: 0x00,
            row: 0x00,
            column: 0x00,
            length: 0x00,
            content: ""

  def new(params \\ []) do
    settings = struct(__MODULE__, params)
    %{settings | length: byte_size(settings.content)}
  end

  def encode(params) do
    settings = new(params)

    <<
      settings.reader,
      fmt_byte(settings),
      settings.time,
      settings.row,
      settings.column,
      settings.length
    >> <> settings.content
  end

  defp fmt_byte(%{temporary?: false, wrap?: false}), do: 0x01
  defp fmt_byte(%{temporary?: false, wrap?: true}), do: 0x02
  defp fmt_byte(%{temporary?: true, wrap?: false}), do: 0x02
  defp fmt_byte(%{temporary?: true, wrap?: true}), do: 0x03
end

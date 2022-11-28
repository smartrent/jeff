defmodule Jeff.Reply.OutputStatus do
  @moduledoc """
  Output Status Report

  OSDP v2.2 Specification Reference: 7.8
  """

  defstruct [:outputs]

  @type state :: :active | :inactive

  @type t :: %__MODULE__{
          outputs: %{non_neg_integer() => state()}
        }

  @spec new(map()) :: t()
  def new(outputs) do
    %__MODULE__{
      outputs: outputs
    }
  end

  @spec decode(<<_::_*8>>) :: t()
  def decode(data) do
    for(<<input::8 <- data>>, do: output_status(input))
    |> Enum.with_index(&{&2, &1})
    |> Enum.into(%{})
    |> new()
  end

  defp output_status(0x00), do: :inactive
  defp output_status(_), do: :active
end

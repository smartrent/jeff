defmodule Jeff.Reply.InputStatus do
  @moduledoc """
  Input Status Report

  OSDP v2.2 Specification Reference: 7.7
  """

  defstruct [:inputs]

  @type state :: :active | :inactive

  @type t :: %__MODULE__{
          inputs: %{non_neg_integer() => state()}
        }

  @spec new(map()) :: t()
  def new(inputs) do
    %__MODULE__{
      inputs: inputs
    }
  end

  @spec decode(<<_::_*8>>) :: t()
  def decode(data) do
    for(<<input::8 <- data>>, do: input_status(input))
    |> Enum.with_index(&{&2, &1})
    |> Enum.into(%{})
    |> new()
  end

  defp input_status(0x00), do: :inactive
  defp input_status(_), do: :active
end

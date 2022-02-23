defmodule Jeff.Command.ComSettings do
  @moduledoc """
  Communication configuration command

  OSDP v2.2 Specification Reference: 6.13
  """

  defstruct address: 0x00,
            baud: 9600

  @type baud() :: 9600

  @type t :: %__MODULE__{
          address: Jeff.osdp_address(),
          baud: baud()
        }

  @type param() ::
          {:address, Jeff.osdp_address()}
          | {:baud, baud()}
  @type params :: t() | [param()]

  @spec new(params()) :: t()
  def new(params \\ []) do
    struct(__MODULE__, params)
  end

  @spec encode(params()) :: binary()
  def encode(params) do
    %{address: address, baud: baud} = new(params)
    <<address, baud::size(4)-unit(8)-little>>
  end
end

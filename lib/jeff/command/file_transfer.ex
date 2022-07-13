defmodule Jeff.Command.FileTransfer do
  @moduledoc """
  File Transfer Command Settings

  OSDP v2.2 Specification Reference: 6.26
  """

  defstruct type: 1,
            total_size: 0,
            offset: 0,
            fragment_size: 0,
            data: <<>>

  @type t :: %__MODULE__{
          type: 1..255,
          total_size: non_neg_integer(),
          offset: non_neg_integer(),
          data: binary(),
        }

  @type param() ::
          {:type, 1..255}
          | {:total_size, non_neg_integer()}
          | {:offset, non_neg_integer()}
          | {:fragment_size, non_neg_integer()}
          | {:data, binary()}
  @type params() :: t() | [param()]

  @spec new(params()) :: t()
  def new(params) do
    struct(__MODULE__, params)
  end

  @spec encode(params()) :: binary()
  def encode(params) do
    settings = new(params)

    <<
      settings.type,
      settings.total_size::size(4)-unit(8)-little,
      settings.offset::size(4)-unit(8)-little,
      settings.fragment_size::size(2)-unit(8)-little,
      settings.data::binary
    >>
  end
end

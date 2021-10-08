defmodule Jeff.Events.CardRead do
  @moduledoc """
  Event that is triggered when readers receive input from card reads
  """

  @type t :: %__MODULE__{
    address: 0..127,
    data: binary(),
    format: non_neg_integer(),
    length: non_neg_integer(),
    reader: non_neg_integer()
  }
  defstruct ~w[address data format length reader]a

  alias Jeff.Reply

  @spec from_reply(Reply.t()) :: t()
  def from_reply(%Reply{} = reply) do
    %__MODULE__{
      address: reply.address,
      data: reply.data.data,
      format: reply.data.format,
      length: reply.data.length,
      reader: reply.data.reader
    }
  end
end

defmodule Jeff.Events.Keypress do
  @moduledoc """
  Event that is triggered when readers receive input to keypads
  """

  @type t :: %__MODULE__{
    address: 0..127,
    count: non_neg_integer(),
    keys: binary(),
    reader: non_neg_integer()
  }

  defstruct ~w[address count keys reader]a

  @spec from_reply(Reply.t()) :: t()
  def from_reply(reply) do
    %__MODULE__{
      address: reply.address,
      count: reply.data.count,
      keys: reply.data.keys,
      reader: reply.data.reader
    }
  end
end

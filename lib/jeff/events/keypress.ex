defmodule Jeff.Events.Keypress do
  @moduledoc """
  Event that is triggered when readers receive input to keypads
  """

  @type t :: %__MODULE__{
          address: Jeff.osdp_address(),
          count: non_neg_integer(),
          keys: binary(),
          reader: non_neg_integer()
        }

  defstruct ~w[address count keys reader]a

  alias Jeff.Reply

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

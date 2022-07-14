defmodule Jeff.Reply.EncryptionClient do
  @moduledoc false

  defstruct [:cuid, :rnd, :cryptogram]

  @type t :: %__MODULE__{
          cuid: <<_::64>>,
          rnd: <<_::64>>,
          cryptogram: <<_::128>>
        }

  @spec decode(<<_::256>>) :: t()
  def decode(<<
        cuid::binary-size(8),
        rnd::binary-size(8),
        cryptogram::binary-size(16)
      >>) do
    %__MODULE__{cuid: cuid, rnd: rnd, cryptogram: cryptogram}
  end
end

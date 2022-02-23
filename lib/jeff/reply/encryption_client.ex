defmodule Jeff.Reply.EncryptionClient do
  @moduledoc false

  defstruct [:cuid, :rnd, :cryptogram]

  def decode(<<
        cuid::binary-size(8),
        rnd::binary-size(8),
        cryptogram::binary-size(16)
      >>) do
    %__MODULE__{cuid: cuid, rnd: rnd, cryptogram: cryptogram}
  end
end

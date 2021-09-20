defmodule CommandEncryptionKeyTest do
  use ExUnit.Case

  alias Jeff.Command.EncryptionKey

  test "encode" do
    key = "foo"

    assert EncryptionKey.encode(key: key) == <<0x01, 0x03, "foo">>
  end
end

defmodule ReplyEncryptionClientTest do
  use ExUnit.Case

  alias Jeff.Reply.EncryptionClient

  test "decode" do
    encryption_client =
      "5C26231902000002
       FDC514DD850E445B
       2C2E97B6EF0881133C364F17CC34A31A"
      |> Base.decode16!()
      |> EncryptionClient.decode()

    assert %EncryptionClient{} = encryption_client
    assert Base.encode16(encryption_client.cuid) == "5C26231902000002"
    assert Base.encode16(encryption_client.rnd) == "FDC514DD850E445B"
    assert Base.encode16(encryption_client.crytogram) == "2C2E97B6EF0881133C364F17CC34A31A"
  end
end

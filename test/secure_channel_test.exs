defmodule SecureChannelTest do
  use ExUnit.Case

  alias Jeff.Reply.EncryptionClient
  alias Jeff.SecureChannel, as: SC

  test "starting a secure channel" do
    sc = SC.new()
    assert byte_size(sc.server_rnd) == 8
  end

  test "generating keys" do
    scbk_d_key = to_bin("303132333435363738393A3B3C3D3E3F")
    server_rnd = to_bin("B0B1B2B3B4B5B6B7")
    client_rnd = to_bin("A0A1A2A3A4A5A6A7")

    smac1 = to_bin("5E86C676603BDEE2D8BEAFE178637332")
    smac2 = to_bin("6FDA86E857777E81132035758239172E")
    enc = to_bin("BF8DC2A8329ACB8C67C6D0CD9A451682")
    server_cryptogram = to_bin("26D3356E07762D262801FC8E6665A891")
    client_cryptogram = to_bin("FDE5D2F428EC16312471EA3C02BD7796")

    key = scbk_d_key
    rnd = server_rnd
    assert SC.gen_smac1(rnd, key) == smac1
    assert SC.gen_smac2(rnd, key) == smac2
    assert SC.gen_enc(rnd, key) == enc

    assert SC.gen_client_cryptogram(server_rnd, client_rnd, enc) == client_cryptogram
    assert SC.gen_server_cryptogram(client_rnd, server_rnd, enc) == server_cryptogram
  end

  test "initializing" do
    scbk_d_key = to_bin("303132333435363738393A3B3C3D3E3F")
    server_rnd = to_bin("B0B1B2B3B4B5B6B7")
    client_rnd = to_bin("A0A1A2A3A4A5A6A7")
    cuid = to_bin("00068E0000000000")

    smac1 = to_bin("5E86C676603BDEE2D8BEAFE178637332")
    smac2 = to_bin("6FDA86E857777E81132035758239172E")
    enc = to_bin("BF8DC2A8329ACB8C67C6D0CD9A451682")
    server_cryptogram = to_bin("26D3356E07762D262801FC8E6665A891")
    client_cryptogram = to_bin("FDE5D2F428EC16312471EA3C02BD7796")

    encryption_client = %EncryptionClient{
      cryptogram: client_cryptogram,
      cuid: cuid,
      rnd: client_rnd
    }

    sc =
      SC.new(scbk: scbk_d_key, server_rnd: server_rnd)
      |> SC.initialize(encryption_client)

    assert %{
             smac1: ^smac1,
             smac2: ^smac2,
             enc: ^enc,
             server_cryptogram: ^server_cryptogram
           } = sc
  end

  defp to_bin(hex), do: Base.decode16!(hex)
end

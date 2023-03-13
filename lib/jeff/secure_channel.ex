defmodule Jeff.SecureChannel do
  @moduledoc false

  import Bitwise

  defstruct [
    :enc,
    :established?,
    :initialized?,
    :failed?,
    :scbk,
    :server_cryptogram,
    :server_rnd,
    :smac1,
    :smac2,
    :rmac,
    :cmac,
    :scbkd?
  ]

  @type t :: %__MODULE__{}

  @typedoc "Secure Channel Base Key"
  @type scbk :: <<_::128>>

  @scbk_default Base.decode16!("303132333435363738393A3B3C3D3E3F")
  @padding_start 0x80

  @spec new(keyword()) :: %__MODULE__{
          scbk: binary(),
          server_rnd: binary(),
          initialized?: false,
          established?: false,
          failed?: false,
          scbkd?: boolean()
        }
  def new(opts \\ []) do
    scbk = opts[:scbk] || @scbk_default
    server_rnd = Keyword.get(opts, :server_rnd, :rand.bytes(8))

    %__MODULE__{
      scbk: scbk,
      server_rnd: server_rnd,
      initialized?: false,
      established?: false,
      failed?: false,
      scbkd?: scbk == @scbk_default
    }
  end

  @spec initialize(t(), Jeff.Reply.EncryptionClient.t()) :: {:ok, t()} | :error
  def initialize(
        %{scbk: scbk, server_rnd: server_rnd} = sc,
        %{cryptogram: client_cryptogram, cuid: _cuid, rnd: client_rnd}
      ) do
    enc = gen_enc(server_rnd, scbk)

    # verify client cryptogram
    if client_cryptogram == gen_client_cryptogram(server_rnd, client_rnd, enc) do
      smac1 = gen_smac1(server_rnd, scbk)
      smac2 = gen_smac2(server_rnd, scbk)
      server_cryptogram = gen_server_cryptogram(client_rnd, server_rnd, enc)

      {:ok,
       %{
         sc
         | enc: enc,
           server_cryptogram: server_cryptogram,
           smac1: smac1,
           smac2: smac2,
           initialized?: true
       }}
    else
      :error
    end
  end

  @spec establish(t(), binary()) :: t()
  def establish(sc, rmac) do
    %{sc | rmac: rmac, established?: true}
  end

  @spec calculate_mac(t(), binary(), boolean()) :: t()
  def calculate_mac(sc, data, command?) do
    iv = if command?, do: sc.rmac, else: sc.cmac

    mac = do_calculate_mac(sc, data, iv)

    if command? do
      %{sc | cmac: mac}
    else
      %{sc | rmac: mac}
    end
  end

  defp do_calculate_mac(sc, <<block::binary-size(16), rest::binary>> = data, iv)
       when byte_size(data) > 16 do
    key = sc.smac1
    iv = :crypto.crypto_one_time(:aes_128_cbc, key, iv, block, encrypt: true)
    do_calculate_mac(sc, rest, iv)
  end

  defp do_calculate_mac(sc, block, iv) do
    padding_start = <<0x80>>
    key = sc.smac2
    block = block <> padding_start
    zeroes = 16 - byte_size(block)
    block = block <> <<0::size(zeroes)-unit(8)>>

    :crypto.crypto_one_time(:aes_128_cbc, key, iv, block, encrypt: true)
  end

  @spec encrypt(t(), binary()) :: binary()
  def encrypt(sc, data) do
    key = sc.enc

    iv =
      sc.rmac
      |> :binary.bin_to_list()
      |> Enum.map(&(~~~&1 &&& 0xFF))
      |> :binary.list_to_bin()

    :crypto.crypto_one_time(:aes_128_cbc, key, iv, data <> <<@padding_start>>,
      encrypt: true,
      padding: :zero
    )
  end

  @spec decrypt(t(), binary()) :: binary()
  def decrypt(sc, data) do
    key = sc.enc

    iv =
      sc.cmac
      |> :binary.bin_to_list()
      |> Enum.map(&(~~~&1 &&& 0xFF))
      |> :binary.list_to_bin()

    :crypto.crypto_one_time(:aes_128_cbc, key, iv, data, encrypt: false)
    |> :binary.split(<<@padding_start>>)
    |> hd()
  end

  @spec gen_enc(binary(), binary()) :: binary()
  def gen_enc(server_rnd, scbk), do: gen_session_key(<<0x01, 0x82>>, server_rnd, scbk)

  @spec gen_smac1(binary(), binary()) :: binary()
  def gen_smac1(server_rnd, scbk), do: gen_session_key(<<0x01, 0x01>>, server_rnd, scbk)

  @spec gen_smac2(binary(), binary()) :: binary()
  def gen_smac2(server_rnd, scbk), do: gen_session_key(<<0x01, 0x02>>, server_rnd, scbk)

  @spec gen_client_cryptogram(binary(), binary(), binary()) :: binary()
  def gen_client_cryptogram(server_rnd, client_rnd, enc) do
    gen_key(server_rnd <> client_rnd, enc)
  end

  @spec gen_server_cryptogram(binary(), binary(), binary()) :: binary()
  def gen_server_cryptogram(client_rnd, server_rnd, enc) do
    gen_key(client_rnd <> server_rnd, enc)
  end

  defp gen_session_key(pre, rnd, scbk) do
    data = pre <> :binary.part(rnd, 0, 6) <> <<0, 0, 0, 0, 0, 0, 0, 0>>
    gen_key(data, scbk)
  end

  defp gen_key(data, key) do
    :crypto.crypto_one_time(:aes_128_ecb, key, data, true)
  end
end

defmodule Jeff.Device do
  @moduledoc false

  @type device_address :: 0..127
  @type check_scheme :: :checksum | :crc
  @type sequence_number :: 0..3

  @type t :: %__MODULE__{
          address: device_address(),
          check_scheme: check_scheme(),
          security?: boolean(),
          secure_channel: term(),
          sequence: sequence_number(),
          commands: :queue.queue(term()),
          last_valid_reply: non_neg_integer()
        }

  defstruct address: 0x7F,
            check_scheme: :checksum,
            security?: false,
            secure_channel: nil,
            sequence: 0,
            commands: :queue.new(),
            last_valid_reply: nil

  alias Jeff.{Command, SecureChannel}

  @offline_threshold_ms 8000

  def new(params \\ []) do
    secure_channel = SecureChannel.new()

    __MODULE__
    |> struct(Keyword.take(params, [:address, :check_scheme, :security?]))
    |> Map.put(:secure_channel, secure_channel)
  end

  def inc_sequence(%{sequence: n} = device) do
    %{device | sequence: next_sequence(n)}
  end

  @spec receive_valid_reply(t()) :: t()
  def receive_valid_reply(device) do
    device |> maybe_set_last_valid_reply() |> inc_sequence()
  end

  defp maybe_set_last_valid_reply(%{sequence: 0} = device), do: device

  defp maybe_set_last_valid_reply(device) do
    %{device | last_valid_reply: System.monotonic_time(:millisecond)}
  end

  defp next_sequence(n), do: rem(n, 3) + 1

  def online?(%{last_valid_reply: nil}), do: false

  def online?(%{last_valid_reply: last_valid_reply}) do
    last_valid_reply - System.monotonic_time(:millisecond) < @offline_threshold_ms
  end

  def send_command(%{commands: commands} = device, command) do
    commands = :queue.in(command, commands)
    %{device | commands: commands}
  end

  def next_command(%{sequence: 0, address: address} = device) do
    command = Command.new(address, POLL)
    {device, command}
  end

  def next_command(
        %{security?: true, secure_channel: %{initialized?: false}, address: address} = device
      ) do
    command = Command.new(address, CHLNG, server_rnd: device.secure_channel.server_rnd)
    {device, command}
  end

  def next_command(
        %{security?: true, secure_channel: %{established?: false}, address: address} = device
      ) do
    command = Command.new(address, SCRYPT, cryptogram: device.secure_channel.server_cryptogram)
    {device, command}
  end

  def next_command(%{commands: {[], []}, address: address} = device) do
    command = Command.new(address, POLL)
    {device, command}
  end

  def next_command(%{commands: commands} = device) do
    {{:value, command}, commands} = :queue.out(commands)
    device = %{device | commands: commands}
    {device, command}
  end
end

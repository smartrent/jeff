defmodule Jeff.Device do
  defstruct address: 0x7F,
            check_scheme: :checksum,
            security?: false,
            secure_channel: nil,
            sequence: 0,
            commands: :queue.new()

  alias Jeff.{Command, SecureChannel}

  def new(params \\ []) do
    secure_channel = SecureChannel.new()

    __MODULE__
    |> struct(Keyword.take(params, [:address, :check_scheme, :security?]))
    |> Map.put(:secure_channel, secure_channel)
  end

  def inc_sequence(%{sequence: n} = device) do
    %{device | sequence: next_sequence(n)}
  end

  defp next_sequence(n), do: rem(n, 3) + 1

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

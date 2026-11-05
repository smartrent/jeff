defmodule Jeff.Device do
  @moduledoc """
  Peripheral Device configuration and handling

  ## Offline detection and reset

  Any reply other than NAK 0x04 (unexpected sequence number) counts as a valid
  reply, including BUSY and other NAKs: the PD is present and talking. A valid
  reply stamps `last_valid_reply`, which drives `online?/1`.

  The offline reset (`maybe_reset_offline/1`) measures silence from the first
  unanswered poll (`unanswered_since`), not from `last_valid_reply`, so the ACU
  never resets a PD that answers every poll, however long a poll round takes.
  On a slow bus (for example, many registered but absent PDs) the time between
  polls of one PD can exceed the threshold; an ACU reset there would restart a
  secure PD's CHLNG/SCRYPT handshake on every turn, so it would never complete.

  The 8s threshold comes from OSDP 2.2 section 5.7: the PD considers its
  communication offline if the period between messages to which it responds
  exceeds 8 seconds, and both sides reset the connection. So the PD resets
  itself when its polls are more than 8s apart, whatever the ACU does. Every
  registered PD that does not answer costs up to the reply timeout (at most
  200ms) per poll round, on top of a fixed 100ms pause per round and the
  replies of the PDs that answer. On a bus with many registered but absent PDs,
  a round can take longer than 8s. A spec-compliant secure PD then drops the
  session between CHLNG and SCRYPT and can never complete the handshake. The
  remedy is to keep a poll round under 8s, for example by not registering PDs
  that are not present, not to change the threshold.
  """

  @type check_scheme :: :checksum | :crc
  @type sequence_number :: 0..3

  @type t :: %__MODULE__{
          address: Jeff.osdp_address(),
          check_scheme: check_scheme(),
          security?: boolean(),
          secure_channel: term(),
          sequence: sequence_number(),
          commands: :queue.queue(term()),
          last_valid_reply: integer() | nil,
          unanswered_since: integer() | nil
        }

  defstruct address: 0x7F,
            check_scheme: :checksum,
            security?: false,
            secure_channel: nil,
            sequence: 0,
            commands: :queue.new(),
            last_valid_reply: nil,
            unanswered_since: nil

  alias Jeff.{Command, SecureChannel}

  @offline_threshold_ms 8000

  @spec new(keyword()) :: t()
  def new(params \\ []) do
    secure_channel = SecureChannel.new()

    __MODULE__
    |> struct(Keyword.take(params, [:address, :check_scheme, :security?]))
    |> Map.put(:secure_channel, secure_channel)
  end

  @spec inc_sequence(t()) :: t()
  def inc_sequence(%{sequence: n} = device) do
    %{device | sequence: next_sequence(n)}
  end

  @doc """
  Resets communication with a PD by setting the sequence number to 0 and resetting
  the secure channel state. Useful when a communication with a PD gets out of sync,
  such as when the PD reboots.

  `last_valid_reply` is left unchanged. It records when the PD last sent a valid
  reply, which a reset does not change, so consumers keep an accurate "last seen"
  time. It is updated again by the next valid reply.

  `unanswered_since` is cleared, so a later offline reset needs a fresh run of
  unanswered polls (see `maybe_reset_offline/1`).
  """
  @spec reset(t()) :: t()
  def reset(device) do
    %{device | sequence: 0, secure_channel: SecureChannel.new(), unanswered_since: nil}
  end

  @doc """
  Records a valid reply from the PD: stamps `last_valid_reply` with the current
  monotonic time (ms), clears `unanswered_since` and advances the sequence
  number. `Jeff.Bus` calls this for every reply except a timeout and NAK 0x04,
  so BUSY and other NAKs count as valid replies.
  """
  @spec receive_valid_reply(t()) :: t()
  def receive_valid_reply(device) do
    %{device | last_valid_reply: System.monotonic_time(:millisecond), unanswered_since: nil}
    |> inc_sequence()
  end

  @doc """
  Records a poll that got no reply. The first one after a reply (or reset)
  stamps `unanswered_since` with the current monotonic time (ms). Later ones
  leave it alone, so it marks when the PD went silent.
  """
  @spec receive_timeout(t()) :: t()
  def receive_timeout(%{unanswered_since: nil} = device) do
    %{device | unanswered_since: System.monotonic_time(:millisecond)}
  end

  def receive_timeout(device), do: device

  defp next_sequence(n), do: rem(n, 3) + 1

  @doc """
  Returns `true` if the PD has sent a valid reply within the offline threshold.
  A PD that has never replied is offline. A reset does not change the result,
  since it keeps `last_valid_reply`.
  """
  @spec online?(t()) :: boolean()
  def online?(%{last_valid_reply: nil}), do: false

  def online?(%{last_valid_reply: last_valid_reply}) do
    System.monotonic_time(:millisecond) - last_valid_reply < @offline_threshold_ms
  end

  @doc """
  Resets the PD to sequence number 0 if communication was established (non-zero
  sequence) and the PD has left polls unanswered for longer than the offline
  threshold, counted from the first unanswered poll (`unanswered_since`). See
  "Offline detection and reset" in the module doc for why silence is timed this
  way and how it relates to OSDP 2.2 section 5.7.

  The reset keeps `last_valid_reply` (see `reset/1`), so the PD stays offline
  until it sends a new valid reply. A PD already at sequence 0 is left alone, so
  a PD that stays absent is reset only once rather than on every poll.
  """
  @spec maybe_reset_offline(t()) :: t()
  def maybe_reset_offline(%{sequence: 0} = device), do: device
  def maybe_reset_offline(%{unanswered_since: nil} = device), do: device

  def maybe_reset_offline(%{unanswered_since: since} = device) do
    if System.monotonic_time(:millisecond) - since < @offline_threshold_ms,
      do: device,
      else: reset(device)
  end

  @spec send_command(t(), Command.t()) :: t()
  def send_command(%{commands: commands} = device, command) do
    commands = :queue.in(command, commands)
    %{device | commands: commands}
  end

  @spec next_command(t()) :: {t(), Command.t()}
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

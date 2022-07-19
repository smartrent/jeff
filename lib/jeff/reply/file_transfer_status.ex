defmodule Jeff.Reply.FileTransferStatus do
  @moduledoc """
  File Transfer Status (osdp_FTSTAT)

  OSDP v2.2 Specification Reference: 7.25
  """

  defstruct [
    :separate_poll_response?,
    :leave_secure_channel?,
    :interleave_ok?,
    :delay,
    :status,
    :update_msg_max
  ]

  @type status ::
          :ok
          | :processed
          | :rebooting
          | :finishing
          | :abort
          | :unrecognized_contents
          | :malformed
          | integer()

  @type t :: %__MODULE__{
          separate_poll_response?: boolean(),
          leave_secure_channel?: boolean(),
          interleave_ok?: boolean(),
          delay: pos_integer(),
          status: status(),
          update_msg_max: pos_integer()
        }

  @spec decode(binary()) :: t()
  def decode(
        <<_::5, spr::1, leave::1, interleave::1, delay::16-little, status::16-little-signed,
          update_msg_max::16-little>>
      ) do
    %__MODULE__{
      separate_poll_response?: spr == 1,
      leave_secure_channel?: leave == 1,
      interleave_ok?: interleave == 1,
      delay: delay,
      status: decode_status(status),
      update_msg_max: update_msg_max
    }
  end

  defp decode_status(0), do: :ok
  defp decode_status(1), do: :processed
  defp decode_status(2), do: :rebooting
  defp decode_status(3), do: :finishing
  defp decode_status(-1), do: :abort
  defp decode_status(-2), do: :unrecognized_contents
  defp decode_status(-3), do: :malformed
  # All other statuses are reserved - Report the raw status for now
  defp decode_status(status), do: status
end

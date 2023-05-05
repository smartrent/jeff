defmodule Jeff do
  @moduledoc """
  Control an Access Control Unit (ACU) and send commands to a Peripheral Device (PD)
  """

  alias Jeff.ACU
  alias Jeff.Command
  alias Jeff.Device
  alias Jeff.MFG.Encoder
  alias Jeff.Reply
  alias Jeff.Reply.ErrorCode

  @type acu() :: GenServer.server()
  @type device_opt() :: ACU.device_opt()
  @type osdp_address() :: 0x00..0x7F
  @type vendor_code() :: 0x000000..0xFFFFFF

  @type cmd_err :: {:error, :timeout | ErrorCode.t()}

  @doc """
  Enable OSDP packet tracing

  Use log level `:debug`

  Available options:
    * `:ignore_polls` - OSDP polling has to occur at minimum every 200ms which
      can be noisy in the logs. When this is set, poll commands and ACK messages
      are ignored when tracing. Default `true`

    * `:ignore_partials` - Partial packets should be rare, but do occur when there
      is noise on the lines or during other communication synchronization problems.
      This ignores partial, incomplete packets when enabled. Default `false`

    * `:ignore_marks` - Before sending data, the the line is driven with a 0xFF
      byte to mark it for sending. This happens on ACU and PD. This is not always
      useful when tracing, so they can be ignored if all the partial bytes are
      0xFF. Default `true`

    * `:partials_limit` - Limit of partial packets to store in a buffer. This is
      most typically not used since partials get logged on next valid packet.
      However, it protects against cases where valid packets may not be happening
      and prevents the partial buffer from growing unbounded. Default `100`

  Tracing can also be configuraed in the application config with the same
  values using the `:tracer` key:

  ```
  config :jeff, :tracer,
    enabled: true,
    ignore_polls: true,
    ignore_partials: false,
    ignore_marks: true
  ```
  """
  @spec enable_trace(acu(), [Jeff.Tracer.option()]) :: :ok | {:error, File.posix()}
  def enable_trace(acu, opts \\ []) do
    GenServer.call(Jeff.ACU.state(acu).conn, {:set_trace, true, opts})
  end

  @doc """
  Disable OSDP packet tracing
  """
  @spec disable_trace(acu()) :: :ok | {:error, File.posix()}
  def disable_trace(acu) do
    GenServer.call(Jeff.ACU.state(acu).conn, {:set_trace, false, []})
  end

  @doc """
  Start an ACU process.
  """
  @spec start_acu([ACU.start_opt()]) :: GenServer.on_start()
  def start_acu(opts \\ []) do
    ACU.start_link(opts)
  end

  @doc """
  Register a peripheral device on the ACU communication bus.
  """
  @spec add_pd(acu(), osdp_address(), [device_opt()]) :: Device.t()
  def add_pd(acu, address, opts \\ []) do
    ACU.add_device(acu, address, opts)
  end

  @doc """
  Remove a peripheral device from the ACU communication bus.
  """
  @spec remove_pd(acu(), osdp_address()) :: Device.t()
  def remove_pd(acu, address) do
    ACU.remove_device(acu, address)
  end

  @doc """
  Requests the return of the PD ID Report.
  """
  @spec id_report(acu(), osdp_address()) :: Reply.IdReport.t() | cmd_err()
  def id_report(acu, address) do
    ACU.send_command(acu, address, ID) |> handle_reply()
  end

  @doc """
  Requests the PD to return a list of its functional capabilities, such as the
  type and number of input points, outputs points, reader ports, etc.
  """
  @spec capabilities(acu(), osdp_address()) :: Reply.Capabilities.t() | cmd_err()
  def capabilities(acu, address) do
    ACU.send_command(acu, address, CAP) |> handle_reply()
  end

  @doc """
  Instructs the PD to reply with a local status report.
  """
  @spec local_status(acu(), osdp_address()) :: Reply.LocalStatus.t() | cmd_err()
  def local_status(acu, address) do
    ACU.send_command(acu, address, LSTAT) |> handle_reply()
  end

  @doc """
  Controls the LEDs associated with one or more readers.
  """
  @spec set_led(acu(), osdp_address(), [Command.LedSettings.param()]) ::
          Reply.ACK | cmd_err()
  def set_led(acu, address, params) do
    ACU.send_command(acu, address, LED, params) |> handle_reply()
  end

  @doc """
  Defines commands to a single, monotone audible annunciator (beeper or buzzer)
  that may be associated with a reader.
  """
  @spec set_buzzer(acu(), osdp_address(), [Command.BuzzerSettings.param()]) ::
          Reply.ACK | cmd_err()
  def set_buzzer(acu, address, params) do
    ACU.send_command(acu, address, BUZ, params) |> handle_reply()
  end

  @doc """
  Sets the PD's communication parameters.
  """
  @spec set_com(acu(), osdp_address(), [Command.ComSettings.param()]) ::
          Reply.ComData.t() | cmd_err()
  def set_com(acu, address, params) do
    ACU.send_command(acu, address, COMSET, params) |> handle_reply()
  end

  @doc """
  Instructs the PD to reply with an input status report.
  """
  @spec input_status(acu(), osdp_address()) :: Reply.InputStatus.t() | cmd_err()
  def input_status(acu, address) do
    ACU.send_command(acu, address, ISTAT) |> handle_reply()
  end

  @doc """
  Instructs the PD to reply with an output status report.
  """
  @spec output_status(acu(), osdp_address()) :: Reply.OutputStatus.t() | cmd_err()
  def output_status(acu, address) do
    ACU.send_command(acu, address, OSTAT) |> handle_reply()
  end

  @doc """
  Sends a manufacturer-specific command to the PD.
  """
  @spec mfg(acu(), osdp_address(), Encoder.t() | [Command.Mfg.param()]) ::
          Reply.MfgReply.t() | cmd_err()
  def mfg(acu, address, mfg_command) when is_struct(mfg_command) do
    vendor_code = Encoder.vendor_code(mfg_command)
    data = Encoder.encode(mfg_command)

    mfg(acu, address, vendor_code: vendor_code, data: data)
  end

  def mfg(acu, address, params) when is_list(params) do
    ACU.send_command(acu, address, MFG, params) |> handle_reply()
  end

  defp handle_reply({:ok, %{data: %ErrorCode{code: code} = data}}) when code > 0,
    do: {:error, data}

  defp handle_reply({:ok, %{data: data}}), do: data
  defp handle_reply(err), do: err
end

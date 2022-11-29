defmodule Jeff do
  @moduledoc """
  Control an Access Control Unit (ACU) and send commands to a Peripheral Device (PD)
  """

  alias Jeff.{ACU, Command, Device, Reply}

  @type acu() :: GenServer.server()
  @type device_opt() :: ACU.device_opt()
  @type osdp_address() :: 0x00..0x7F

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
  @spec id_report(acu(), osdp_address()) :: Reply.IdReport.t() | Reply.ErrorCode.t()
  def id_report(acu, address) do
    ACU.send_command(acu, address, ID).data
  end

  @doc """
  Requests the PD to return a list of its functional capabilities, such as the
  type and number of input points, outputs points, reader ports, etc.
  """
  @spec capabilities(acu(), osdp_address()) :: Reply.Capabilities.t() | Reply.ErrorCode.t()
  def capabilities(acu, address) do
    ACU.send_command(acu, address, CAP).data
  end

  @doc """
  Instructs the PD to reply with a local status report.
  """
  @spec local_status(acu(), osdp_address()) :: Reply.LocalStatus.t() | Reply.ErrorCode.t()
  def local_status(acu, address) do
    ACU.send_command(acu, address, LSTAT).data
  end

  @doc """
  Controls the LEDs associated with one or more readers.
  """
  @spec set_led(acu(), osdp_address(), [Command.LedSettings.param()]) ::
          Reply.ACK | Reply.ErrorCode.t()
  def set_led(acu, address, params) do
    ACU.send_command(acu, address, LED, params).data
  end

  @doc """
  Defines commands to a single, monotone audible annunciator (beeper or buzzer)
  that may be associated with a reader.
  """
  @spec set_buzzer(acu(), osdp_address(), [Command.BuzzerSettings.param()]) ::
          Reply.ACK | Reply.ErrorCode.t()
  def set_buzzer(acu, address, params) do
    ACU.send_command(acu, address, BUZ, params).data
  end

  @doc """
  Sets the PD's communication parameters.
  """
  @spec set_com(acu(), osdp_address(), [Command.ComSettings.param()]) ::
          Reply.ComData.t() | Reply.ErrorCode.t()
  def set_com(acu, address, params) do
    ACU.send_command(acu, address, COMSET, params).data
  end

  @doc """
  Instructs the PD to reply with an input status report.
  """
  @spec input_status(acu(), osdp_address()) :: Reply.InputStatus.t() | Reply.ErrorCode.t()
  def input_status(acu, address) do
    ACU.send_command(acu, address, ISTAT).data
  end

  @doc """
  Instructs the PD to reply with an output status report.
  """
  @spec output_status(acu(), osdp_address()) :: Reply.InputStatus.t() | Reply.ErrorCode.t()
  def output_status(acu, address) do
    ACU.send_command(acu, address, OSTAT).data
  end
end

defmodule Jeff do
  alias Jeff.ACU

  def start_acu(opts \\ []) do
    ACU.start_link(opts)
  end

  def add_pd(acu, address, opts \\ []) do
    ACU.add_device(acu, address, opts)
  end

  def id_report(acu, address) do
    ACU.send_command(acu, address, ID)
  end

  def capabilities(acu, address) do
    ACU.send_command(acu, address, CAP)
  end

  def local_status(acu, address) do
    ACU.send_command(acu, address, LSTAT)
  end

  def input_status(acu, address) do
    ACU.send_command(acu, address, ISTAT)
  end

  def set_led(acu, address, params) do
    ACU.send_command(acu, address, LED, params)
  end

  def set_buzzer(acu, address, params) do
    ACU.send_command(acu, address, BUZ, params)
  end

  def set_com(acu, address, params) do
    ACU.send_command(acu, address, COMSET, params)
  end

  def set_key(acu, address, params) do
    ACU.send_command(acu, address, KEYSET, params)
  end

  def abort(acu, address) do
    ACU.send_command(acu, address, ABORT)
  end
end

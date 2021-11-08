defmodule Jeff.DeviceDetection do
  @moduledoc """
  Detect OSDP peripheral devices connected to a serial port
  """

  alias Circuits.UART
  alias Jeff.{Command, Message}

  @addresses 0..127
  @speeds [9600, 19200, 38400, 57600, 115_200, 230_400]
  @default_port "ttyUSB0"

  @type poll_status() :: :hit | :miss | :error
  @type speed() :: 9600 | 19200 | 38400 | 57600 | 115_200 | 230_400
  @type address() :: 0..127
  @type poll_response() :: {poll_status(), speed(), address()}

  @doc """
  Scan all possible addresses and speeds to detect OSDP peripheral devices
  connected to a serial port.

  For each speed, addresses 0 - 127 are polled and return tuples with the
  status, speed, and address.
  ```
  [
    {:miss, 9600, 0},
    {:hit, 9600, 1},
    {:error, 9600, 2}
    ...
  ]
  ```
  """
  @spec scan(String.t()) :: list(poll_response())
  def scan(port \\ @default_port) do
    uart = start_uart(port)

    for speed <- @speeds do
      uart = change_uart_speed(uart, speed)

      for address <- @addresses do
        poll(uart, speed, address)
      end
    end
    |> List.flatten()
  end

  defp start_uart(port) do
    {:ok, uart} = UART.start_link()

    uart_opts = [active: false, framing: Jeff.Framing]
    :ok = UART.open(uart, port, uart_opts)

    uart
  end

  defp change_uart_speed(uart, speed) do
    :ok = UART.configure(uart, speed: speed)
    uart
  end

  defp poll(uart, speed, address) do
    :ok = UART.write(uart, <<0xFF>> <> poll_packet(address))

    case UART.read(uart, 50) do
      {:ok, <<>>} -> {:miss, speed, address}
      {:ok, _} -> {:hit, speed, address}
      {:error, _} -> {:error, speed, address}
    end
  end

  defp poll_packet(address) do
    Message.new(
      address: address,
      check_scheme: :checksum,
      sequence: 0,
      security?: false,
      code: Command.code(POLL)
    )
    |> Map.get(:bytes)
  end
end

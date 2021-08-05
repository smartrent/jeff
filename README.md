# Jeff

An Elixir implementation of the Open Supervised Device Protocol (OSDP).

## Example

```
{:ok, cp} = Jeff.ControlPanel.start_link(serial_port: "/dev/ttyUSB0")
Jeff.ControlPanel.add_device(cp, 0x7F, check_scheme: :crc)
Jeff.ControlPanel.id_report(cp, 0x7F)
```

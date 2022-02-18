# Jeff

An Elixir implementation of the Open Supervised Device Protocol (OSDP).

## Example

```
{:ok, cp} = Jeff.ACU.start_link(serial_port: "/dev/ttyUSB0")
Jeff.ACU.add_device(cp, 0x7F, check_scheme: :crc)
Jeff.ACU.id_report(cp, 0x7F)
```

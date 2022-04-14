<img src="./assets/logo.svg" alt="Jeff logo" width="322">

An Elixir implementation of the Open Supervised Device Protocol (OSDP).

[Open Supervised Device Protocol](https://www.securityindustry.org/industry-standards/open-supervised-device-protocol)
(OSDP) is an access control communications standard developed by the Security
Industry Association (SIA).

The OSDP standard describes the communication interface of one or more
Peripheral Devices (PD) to an Access Control Unit (ACU). The specification
describes the protocol implementation over a two-wire RS-485 multi-drop
serial communication channel.

OSDP Supports the control of components on a PD such as:
- LED
- Buzzer
- Keypad
- Output (GPIOs)
- Input Control (GPIOs)
- Displays
- Device status (tamper, power, etc.)
- Card Reader
- Fingerprint Reader

## Example

```elixir
{:ok, acu} = Jeff.start_acu(serial_port: "/dev/ttyUSB0")
Jeff.add_pd(acu, 0x7F, check_scheme: :crc)
Jeff.id_report(acu, 0x7F)
```

## License

Copyright (C) 2022 SmartRent

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

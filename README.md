# Jeff

An Elixir implementation of the Open Supervised Device Protocol (OSDP).

## Example

```
{:ok, cp} = Jeff.ACU.start_link(serial_port: "/dev/ttyUSB0")
Jeff.ACU.add_device(cp, 0x7F, check_scheme: :crc)
Jeff.ACU.id_report(cp, 0x7F)
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

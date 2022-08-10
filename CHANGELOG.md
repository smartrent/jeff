## [v0.4.1] - 2022-08-10

### Added

- Added `:transport_opts` option to `Jeff.ACU.start_link` for passing options
  to the underlying transport.

## [v0.4.0] - 2022-07-29

### Changed

- Capabilities now returns a map. See `Jeff.Reply.Capabilities` for more info.

### Fixed

- Gracefully handle ACU process termination to prevent orphaned Jeff.Transport
  and Circuits.UART processes.

## [v0.3.2] - 2022-04-13

### Added

- Support removal of peripheral devices from ACU bus

## [v0.3.1] - 2022-03-31

### Changed

- Add controlling_process to ACU start opt type

## [v0.3.0] - 2022-03-09

### Changed

- Improve documentation and typespecs
- Improve README and docs
- Rename ControlPanel -> ACU

### Added

- Add LICENSE info

## [v0.2.0] - 2022-02-10

### Added

- Send out-of-band commands: send commands to devices not yet registered to the
  communication bus loop.
- Check OSDP address: Checks whether address is available to register to a bus.

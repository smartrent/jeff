## [v0.6.0] - 2026-11-23

**Potentially Breaking Changes**

`Jeff.Reply.IdReport` now zero-pads each vendor (OUI) byte to two hex digits,
so `vendor` is always 6 characters. Previously, bytes below `0x10` lost their
leading zero (e.g. `<<0x01, 0x01, 0x01>>` was `"111"` and is now `"010101"`).
Update any stored or hard-coded vendor strings that relied on the old format.

### Fixed

- Vendor (OUI) codes in PDID reports are now zero-padded to 6 hex characters
  (CB-305)
- After a NAK for an unexpected sequence number (error code 0x04), the next
  command to that PD is now sent with sequence number 0. Previously the reset
  was undone in the same tick, so the PD was never re-synchronized (CB-310)
- `Jeff.Device.online?/1` now returns `false` once the last valid reply is older
  than the offline threshold. Previously it returned `true` no matter how long
  ago the last reply was (CB-319)

### Changed

- A PD that leaves polls unanswered for longer than the offline threshold (8s),
  counted from the first unanswered poll, is reset to sequence number 0 so
  communication restarts cleanly when it comes back. The ACU does not reset a
  PD that answers every poll, even on a slow bus where its polls are more than
  8s apart. Per OSDP 2.2 section 5.7 the PD itself still goes offline in that
  case, so a poll round should be kept under 8s (CB-319)
- `Jeff.Device.reset/1` no longer sets `last_valid_reply` to `0`. It keeps the
  time of the PD's last valid reply, so consumers keep an accurate "last seen"
  time across NAK and offline resets. A PD that was offline stays offline until
  its next valid reply, and a NAK 0x04 reset no longer marks an online PD as
  offline (CB-319)
- A valid reply to a sequence 0 command now updates `last_valid_reply` (CB-319).
  Any reply other than NAK 0x04 counts as a valid reply, including BUSY and
  other NAKs, so a PD that answers with them is online and is not reset

## [v0.5.2] - 2025-09-30

### Added

- OSDP file transfer command support (#42)

## [v0.5.1] - 2023-05-08

### Added

- OSDP packet tracing (#39) - `Jeff.enable_trace/2` for more details
- Allow specifying timeout for commands (#40)

### Fixed

- Removing non-registered devices no longer crashes the ACU process (#38)

## [v0.5.0] - 2023-04-06

**Breaking Changes**

`Jeff.ACU.send_command/4` and `Jeff.ACU.send_command_oob/4` now return tagged
tuples of `{:ok, Jeff.Reply.t()}` and `{:error, term()}` instead of just the
reply struct. You'll need to update you code if you are relying on the returns
of these functions. Likewise, many of the `Jeff.*` functions were adapted to
return an error tuple when needed.

### Added

- Added Input and Output commands and replies (#32)
- Support Manufacturer specific commands/replies (osdp_MFG and osdp_MFGREP) (#33)
- Use tagged tuples for `send_command` and `send_command_oob` returns (#36)

### Fixed

- Reset communication on sequence number desync (#34)
- Fix request failures to offline devices (#36)

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

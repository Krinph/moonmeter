# Changelog

All notable changes to moonmeter are documented here. This project follows
semantic versioning.

## 0.2.1 — DL/T 645-2007 conformance fix

Corrected the protocol implementation to match the DL/T 645-2007 standard
after review feedback. These are breaking semantic fixes: the previous
definitions conflicted with the standard's frame and control-code tables.

### Fixed

- Length field: was a two-byte little-endian `L(2)` with `13+L` frames;
  now the standard **single-byte L** with `12+L` frames.
- Data field: now applies the mandatory **+0x33 offset on transmit** and
  **-0x33 on receive**, for both requests and replies.
- Control codes: read data `0x01` -> **`0x11`**, normal read reply `0x81` ->
  **`0x91`**, abnormal read reply `0xC1` -> **`0xD1`**; abnormal detection
  now requires D7 (reply) and D6 (abnormal) together.
- Function-code table: was a contiguous `0x01..0x0F`; now the standard
  discrete codes (`0x08`, `0x11..0x1B`), including broadcast time sync
  `0x08` (was `0x05`).
- Data identifiers: forward active total energy is `00010000` (was
  `00000000`), transmitted DI0..DI3; DI metadata now uses standard names,
  units and decimal places.
- `validate_frame` no longer reports a short read reply for abnormal
  replies, which carry a one-byte error code instead of a DI echo.

### Added

- Golden byte-for-byte tests for the standard read request and reply frames
  that decode to `1234.56 kWh`.
- `docs/STANDARD_CONFORMANCE.md`: conformance scope, key message semantics,
  and a full request -> reply -> reading walkthrough with checksum arithmetic.
- `DataId::wire_bytes`, `DataId::to_string`, `normal_reply_control`,
  `abnormal_reply_control`, `has_follow_up`, `offset_data`, `unoffset_data`.
- Test suite expanded from 36 to 43 tests (all passing).

## 0.2.0 — MVP

The first complete, hardware-free reading loop: build a request, simulate a
meter reply, decode and label the reading, format the value, and validate the
wire stream. Ready for library use, CLI debugging and conformance testing.

### Added

- Data-identifier catalog with human-readable names, units and decimal places
  (`di_info`, `di_label`), including a hex fallback for unknown identifiers.
- DL/T 645 error-reply decoding (`ErrorCode`, `decode_error_reply`) for the
  standard error codes carried in `0xC1`-class replies.
- Meter address validation and 12-digit conversion helpers (`valid_address`,
  `address_from_digits`, `address_to_digits`).
- Fixed-point energy formatting (`format_energy`), e.g. `(123456, 2)` -> `1234.56`.
- One-call stream conformance check (`validate_stream`) and severity counting
  (`count_findings`), wired into the `validate` CLI command.
- Public single-byte hex formatter (`hex_byte`).
- A runnable round-trip example at `cmd/roundtrip`.
- Full mooncakes package README (replacing the placeholder).
- Three documented usage scenarios in README and the proposal.

### Changed

- `validate` CLI now reports decoded frames and an error/warning summary.
- `parse` CLI now shows the data-identifier name and any decoded error code.
- Version bumped to 0.2.0; package metadata keywords refreshed.
- Test suite expanded from 16 to 35 tests covering the new API surface.

## 0.1.0 — Initial protocol core

- DL/T 645-2007 frame codec, BCD helpers, data identifiers, common commands,
  meter simulator, conformance validator and four-subcommand CLI.
- Library + CLI dual API, Apache-2.0 license and three-platform CI.

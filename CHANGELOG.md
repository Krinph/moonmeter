# Changelog

All notable changes to moonmeter are documented here. This project follows
semantic versioning.

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

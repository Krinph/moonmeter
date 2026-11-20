# moonmeter

DL/T 645-2007 electricity meter communication protocol stack for MoonBit.

`moonmeter` provides a complete, hardware-free round trip for smart-meter
reading: build a request frame, encode it, simulate a meter reply, decode the
reading, and validate the byte stream for protocol conformance.

## Features

- Frame codec for the DL/T 645-2007 layout (`68H` start, 6-byte BCD address,
  control code, 2-byte length, data field, checksum, `16H` end).
- BCD address / time / energy encoding and decoding (low byte first), plus
  12-digit address validation and conversion helpers.
- A catalog of common data identifiers (active/peak/flat/valley energy,
  voltage, current, power) with human-readable names and units.
- Decoding of DL/T 645 error-reply codes.
- Fixed-point formatting of decoded BCD energy values (e.g. `1234.56 kWh`).
- `MeterSim`: an in-memory meter that answers read requests and can emit
  deliberately corrupted streams for conformance testing.
- A conformance validator that splits a byte stream into frames and reports
  structured findings (stray bytes, bad checksum, bad end, invalid BCD,
  short replies), with a one-call `validate_stream` API.
- A CLI with `parse`, `validate`, `read` and `simulate` subcommands.

## Quick start

```moon
import "Krinph/moonmeter" @moonmeter

let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
let req = @moonmeter.build_read_request(addr, @moonmeter.di_active_total())

let sim = @moonmeter.MeterSim::new(addr)
sim.set_reading(@moonmeter.di_active_total(), [0x56, 0x34, 0x12, 0x00])
let reply = sim.answer_read(req).unwrap()

let frame = @moonmeter.decode_frame(reply).unwrap()
let reading = @moonmeter.parse_reading(frame.data).unwrap()
let (raw, decimals) = @moonmeter.decode_energy(reading.value, 2)
println(@moonmeter.format_energy(raw, decimals) + " kWh")
// 1234.56 kWh
```

CLI:

```text
moon run cmd/main -- read
moon run cmd/main -- parse 68 00 01 02 03 04 05 68 01 04 00 00 00 00 00 E4 16
moon run cmd/main -- simulate
moon run cmd/main -- validate 68 00 01 02 03 04 05 68 81 06 00 00 01 00 01 00 01 69 15
```

A full runnable round-trip example is available in the repository:

```text
moon run cmd/roundtrip
```

See the repository README for full documentation and usage scenarios.

## License

Apache-2.0

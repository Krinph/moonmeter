# moonmeter

DL/T 645-2007 electricity meter communication protocol stack for MoonBit,
conformant to the Chinese multi-function energy meter standard.

`moonmeter` targets full protocol-layer conformance to the current DL/T 645-2007:
all twelve application-layer function codes (08H, 11H..1BH), the three
reply-control families (normal `9x`, follow-up `Bx`, abnormal `Dx`), multi-frame
read-next transfers with sequence numbers, and a complete hardware-free round
trip: build a standard request, simulate a meter reply, decode the reading and
validate the byte stream.

As of 2026-11-25, the national standards platform still lists DL/T 645-2007 as
current with no 202x successor. DL/T 698.45-2017/2026 are separate
object-oriented standards, not upgrades of DL/T 645. Device-specific items
(supported DIs, scaling, permissions, electrical layer) remain subject to the
meter manual; see `docs/STANDARD_CONFORMANCE.md` section 0.

## Features

- Frame codec for the DL/T 645-2007 layout: `68H` start, 6-byte BCD address,
  control code, **single-byte length**, **+33H-encoded data field**, checksum
  and `16H` end.
- Correct control-code semantics: direction (D7), abnormal flag (D6),
  follow-up (D5) and the standard discrete function codes (08H, 11H..1BH).
- BCD address / time / energy encoding and decoding (low byte first), plus
  12-digit address validation and conversion helpers.
- A catalog of common data identifiers (DI3DI2DI1DI0: forward active
  total/peak/flat/shoulder/valley energy, voltage, current, power) with
  standard names, units and decimal places.
- Decoding of `0xD1` abnormal replies into structured error codes.
- Fixed-point formatting of decoded BCD energy values (e.g. `1234.56 kWh`).
- `MeterSim`: an in-memory meter that answers read requests with conformant
  frames and can emit deliberately corrupted streams for conformance testing.
- A conformance validator that splits a byte stream into frames and reports
  structured findings (stray bytes, bad checksum, bad end, invalid BCD,
  short or overlong semantic replies, undefined function codes), while treating
  the standard wildcard address byte `0xAA` as legal; with a one-call
  `validate_stream` API.
- Multi-frame interaction: read-next-data (0x12) frame sequence construction,
  parsing and matching, covering normal / follow-up / abnormal reply semantics.
- A CLI with `parse`, `validate`, `read`, `commands` and `simulate` subcommands;
  `commands` prints all function codes and reply control bytes.

## Quick start

```moon
import "Krinph/moonmeter" @moonmeter

// DI 00010000 = current forward active total energy.
let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
let req = @moonmeter.build_read_request(addr, @moonmeter.di_active_total())
// -> 68 00 01 02 03 04 05 68 11 04 33 33 34 33 C1 16

let sim = @moonmeter.MeterSim::new(addr)
sim.set_reading(@moonmeter.di_active_total(), [0x56, 0x34, 0x12, 0x00])
let reply = sim.answer_read(req).unwrap()

let frame = @moonmeter.decode_frame(reply).unwrap()
let reading = @moonmeter.parse_reading(frame.data).unwrap()
let info = @moonmeter.di_info(reading.di).unwrap()
let (raw, decimals) = @moonmeter.decode_energy(reading.value, info.decimals)
println(@moonmeter.format_energy(raw, decimals) + " " + info.unit)
// 1234.56 kWh
```

CLI:

```text
moon run cmd/main -- --address 129078563412 read
moon run cmd/main -- parse "68 12 90 78 56 34 12 68 91 08 33 33 34 33 89 67 45 33 54 16"
moon run cmd/main -- simulate
moon run cmd/main -- commands
moon run cmd/main -- validate "68 12 90 78 56 34 12 68 91 08 33 33 34 33 89 67 45 33 54 16"
```

A full runnable round-trip example is available in the repository:

```text
moon run cmd/roundtrip
```

The byte-by-byte golden frames, checksum calculation and conformance scope
are documented in `docs/STANDARD_CONFORMANCE.md` in the repository.

## License

Apache-2.0

///|
/// White-box tests for the DL/T 645-2007 core: frame codec, BCD, commands,
/// validator and simulator.

///|
fn test_address() -> Array[Byte] {
  [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
}

///|
test "frame: round-trip encode/decode with single-byte length and +0x33" {
  let addr = test_address()
  let data : Array[Byte] = [0x00, 0x01, 0x02, 0x03]
  let bytes = encode_frame(addr, 0x11, data)
  // 68 ADDR[6] 68 C L DATA[4] CS 16 = 16 bytes (12 + L).
  assert_eq(bytes.length(), 16)
  assert_eq(bytes[0], 0x68)
  assert_eq(bytes[7], 0x68)
  assert_eq(bytes[8], 0x11)
  assert_eq(bytes[9], 4)
  // DATA on the wire is offset by +0x33.
  assert_eq(bytes[10], 0x33)
  assert_eq(bytes[11], 0x34)
  assert_eq(bytes[12], 0x35)
  assert_eq(bytes[13], 0x36)
  let frame = decode_frame(bytes).unwrap()
  assert_eq(frame.control, 0x11)
  assert_eq(frame.address.length(), 6)
  assert_eq(frame.data.length(), 4)
  assert_eq(frame.data[0], 0x00)
  assert_eq(frame.data[3], 0x03)
}

///|
test "frame: checksum is validated" {
  let addr = test_address()
  let bytes = encode_frame(addr, 0x11, [0x00, 0x00, 0x00, 0x00])
  // Corrupt one DATA byte on the wire.
  bytes[10] = 0xFF
  match decode_frame(bytes) {
    Err(FrameError::BadChecksum) => ()
    _ => fail("expected BadChecksum")
  }
}

///|
test "frame: rejects bad start and end" {
  let addr = test_address()
  let bytes = encode_frame(addr, 0x11, [])
  assert_eq(bytes.length(), 12)
  bytes[0] = 0x69
  assert_true(decode_frame(bytes) is Err(_))
  let bytes2 = encode_frame(addr, 0x11, [])
  let last = bytes2.length() - 1
  bytes2[last] = 0x15
  assert_true(decode_frame(bytes2) is Err(_))
}

///|
test "frame: +0x33 offset wraps correctly at 0xFF" {
  let wire = offset_data([0xCC, 0xFF, 0x00])
  assert_eq(wire[0], 0xFF)
  assert_eq(wire[1], 0x32)
  assert_eq(wire[2], 0x33)
  let back = unoffset_data(wire[:])
  assert_eq(back[0], 0xCC)
  assert_eq(back[1], 0xFF)
  assert_eq(back[2], 0x00)
}

///|
test "bcd: encode and decode round-trip" {
  assert_eq(bcd_from(23).to_int(), 0x23)
  assert_eq(bcd_to(0x23), 23)
  assert_eq(bcd_to(0x99), 99)
  let encoded = bcd_encode(123456, 6)
  assert_eq(encoded.length(), 3)
  assert_eq(bcd_to(encoded[0]), 56)
  assert_eq(bcd_to(encoded[1]), 34)
  assert_eq(bcd_to(encoded[2]), 12)
  assert_eq(bcd_decode(encoded), 123456)
}

///|
test "commands: read request uses control 0x11" {
  let addr = test_address()
  let req = build_read_request(addr, di_active_total())
  let frame = decode_frame(req).unwrap()
  assert_eq(frame.control, 0x11)
  assert_eq(frame.data.length(), 4)
  // DI 00010000 wire order = DI0..DI3 = 00 00 01 00.
  assert_eq(frame.data[2], 0x01)
}

///|
test "commands: broadcast time sync uses control 0x08" {
  let addr : Array[Byte] = [0x99, 0x99, 0x99, 0x99, 0x99, 0x99]
  let sync = build_time_sync(addr, 20261118, 93012)
  let frame = decode_frame(sync).unwrap()
  assert_eq(frame.control, 0x08)
  assert_eq(frame.data.length(), 6)
  assert_eq(bcd_to(frame.data[0]), 26)
  assert_eq(bcd_to(frame.data[1]), 11)
  assert_eq(bcd_to(frame.data[2]), 18)
  assert_eq(bcd_to(frame.data[3]), 09)
  assert_eq(bcd_to(frame.data[4]), 30)
  assert_eq(bcd_to(frame.data[5]), 12)
}

///|
test "commands: parse reading reply" {
  let reply_data : Array[Byte] = [
    0x00, 0x00, 0x01, 0x00, 0x56, 0x34, 0x12, 0x00,
  ]
  let reading = parse_reading(reply_data).unwrap()
  assert_eq(reading.di.to_string(), "00010000")
  assert_eq(reading.value.length(), 4)
  let raw = bcd_decode(reading.value)
  assert_eq(raw, 123456)
}

///|
test "validator: clean stream has no findings" {
  let sim = MeterSim::new(test_address())
  sim.set_reading(di_active_total(), [0x56, 0x34, 0x12, 0x00])
  sim.set_reading(di_voltage(), [0x01, 0x23])
  let stream = sim.generate_stream(false)
  let (frames, findings) = split_frames(stream)
  assert_eq(frames.length(), 2)
  assert_eq(findings.length(), 0)
}

///|
test "validator: corrupted stream is flagged" {
  let sim = MeterSim::new(test_address())
  sim.set_reading(di_active_total(), [0x56, 0x34, 0x12, 0x00])
  let stream = sim.generate_stream(true)
  let (frames, findings) = split_frames(stream)
  assert_eq(frames.length(), 1)
  assert_true(findings.length() > 0)
  let has_end = findings.filter(fn(f) { f.code == "bad_end" }).length()
  assert_true(has_end > 0)
}

///|
test "validator: stray byte between frames is reported" {
  let sim = MeterSim::new(test_address())
  sim.set_reading(di_active_total(), [0x56, 0x34, 0x12, 0x00])
  let stream = sim.generate_stream(false)
  let padded : Array[Byte] = [0x55]
  for b in stream {
    padded.push(b)
  }
  let (frames, findings) = split_frames(padded)
  assert_eq(frames.length(), 1)
  assert_true(findings.length() > 0)
  assert_true(findings[0].code == "stray_byte")
}

///|
test "validator: FE preamble is skipped without a finding" {
  let sim = MeterSim::new(test_address())
  sim.set_reading(di_active_total(), [0x56, 0x34, 0x12, 0x00])
  let stream = sim.generate_stream(false)
  let padded : Array[Byte] = [0xFE, 0xFE, 0xFE, 0xFE]
  for b in stream {
    padded.push(b)
  }
  let (frames, findings) = split_frames(padded)
  assert_eq(frames.length(), 1)
  assert_eq(findings.length(), 0)
}

///|
test "simulator: answers a read request with a 0x91 reply" {
  let sim = MeterSim::new(test_address())
  sim.set_reading(di_active_total(), [0x56, 0x34, 0x12, 0x00])
  let req = build_read_request(test_address(), di_active_total())
  let reply = sim.answer_read(req).unwrap()
  let frame = decode_frame(reply).unwrap()
  assert_eq(frame.control, 0x91)
  assert_eq(frame.data.length(), 8)
  let reading = parse_reading(frame.data).unwrap()
  assert_eq(reading.value.length(), 4)
  assert_eq(bcd_decode(reading.value), 123456)
}

///|
test "simulator: unknown DI yields no reply" {
  let sim = MeterSim::new(test_address())
  sim.set_reading(di_active_total(), [0x56, 0x34, 0x12, 0x00])
  let req = build_read_request(test_address(), di_voltage())
  assert_true(sim.answer_read(req) is None)
}

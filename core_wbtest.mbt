///|
/// White-box tests for the DL/T 645 core: frame codec, BCD, commands,
/// validator and simulator.

///|
fn test_address() -> Array[Byte] {
  [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
}

///|
test "frame: round-trip encode/decode" {
  let addr = test_address()
  let data : Array[Byte] = [0x00, 0x00, 0x00, 0x00]
  let bytes = encode_frame(addr, 0x01, data)
  // 1 + 6 + 1 + 1 + 2 + 4 + 1 + 1 = 17
  assert_eq(bytes.length(), 17)
  assert_eq(bytes[0], 0x68)
  assert_eq(bytes[7], 0x68)
  assert_eq(bytes[8], 0x01)
  let frame = decode_frame(bytes).unwrap()
  assert_eq(frame.control, 0x01)
  assert_eq(frame.address.length(), 6)
  assert_eq(frame.data.length(), 4)
  assert_eq(frame.data[0], 0x00)
}

///|
test "frame: checksum is validated" {
  let addr = test_address()
  let bytes = encode_frame(addr, 0x01, [0x00, 0x00, 0x00, 0x00])
  // Corrupt one byte in the data field.
  bytes[11] = 0xFF
  let err = decode_frame(bytes)
  assert_true(err is Err(_))
  match err {
    Err(FrameError::BadChecksum) => ()
    _ => fail("expected BadChecksum")
  }
}

///|
test "frame: rejects bad start and end" {
  let addr = test_address()
  let bytes = encode_frame(addr, 0x01, [])
  bytes[0] = 0x69
  assert_true(decode_frame(bytes) is Err(_))
  let bytes2 = encode_frame(addr, 0x01, [])
  let last = bytes2.length() - 1
  bytes2[last] = 0x15
  assert_true(decode_frame(bytes2) is Err(_))
}

///|
test "bcd: encode and decode round-trip" {
  assert_eq(bcd_from(23).to_int(), 0x23)
  assert_eq(bcd_to(0x23), 23)
  assert_eq(bcd_to(0x99), 99)
  let encoded = bcd_encode(123456, 6)
  assert_eq(encoded.length(), 3)
  // 123456 = 56 34 12 (low first)
  assert_eq(bcd_to(encoded[0]), 56)
  assert_eq(bcd_to(encoded[1]), 34)
  assert_eq(bcd_to(encoded[2]), 12)
  assert_eq(bcd_decode(encoded), 123456)
}

///|
test "commands: read request frame shape" {
  let addr = test_address()
  let req = build_read_request(addr, di_active_total())
  let frame = decode_frame(req).unwrap()
  assert_eq(frame.control, 0x01)
  assert_eq(frame.data.length(), 4)
  assert_eq(frame.data[0], 0x00)
  assert_eq(frame.data[3], 0x00)
}

///|
test "commands: time sync frame" {
  let addr : Array[Byte] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let sync = build_time_sync(addr, 20261118, 93012)
  let frame = decode_frame(sync).unwrap()
  assert_eq(frame.control, 0x05)
  assert_eq(frame.data.length(), 6)
  // YY=26 MM=11 DD=18 hh=09 mm=30 ss=12
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
    0x00, 0x00, 0x00, 0x00, 0x56, 0x34, 0x12, 0x00,
  ]
  let reading = parse_reading(reply_data).unwrap()
  assert_eq(reading.di.di3, 0x00)
  assert_eq(reading.value.length(), 4)
  // 1234.56 kWh encoded as BCD 56 34 12 00 (low byte first) -> 123456 (0.01 kWh)
  let raw = bcd_decode(reading.value)
  assert_eq(raw, 123456)
}

///|
test "validator: clean stream has no findings" {
  let sim = MeterSim::new(test_address())
  sim.set_reading(di_active_total(), [0x56, 0x34, 0x12, 0x00])
  sim.set_reading(di_voltage(), [0x01, 0x00])
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
  // The last frame has a corrupted ending byte.
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
  let padded : Array[Byte] = []
  padded.push(0x55)
  for b in stream {
    padded.push(b)
  }
  let (frames, findings) = split_frames(padded)
  assert_eq(frames.length(), 1)
  assert_true(findings.length() > 0)
  assert_true(findings[0].code == "stray_byte")
}

///|
test "simulator: answers a read request" {
  let sim = MeterSim::new(test_address())
  sim.set_reading(di_active_total(), [0x56, 0x34, 0x12, 0x00])
  let req = build_read_request(test_address(), di_active_total())
  let reply = sim.answer_read(req).unwrap()
  let frame = decode_frame(reply).unwrap()
  assert_eq(frame.control, 0x81)
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

///|
test "control helpers" {
  assert_true(is_reply(0x81))
  assert_true(!is_reply(0x01))
  assert_true(is_error_reply(0xC1))
  assert_eq(function_code(0x81), 0x01)
  assert_eq(function_code(0x01), 0x01)
}

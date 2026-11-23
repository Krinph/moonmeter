///|
/// White-box tests for the combined stream validator.

///|
test "validate_stream: clean stream yields frames and no findings" {
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let sim = MeterSim::new(addr)
  sim.set_reading(di_active_total(), [0x56, 0x34, 0x12, 0x00])
  let stream = sim.generate_stream(false)
  let (frames, findings) = validate_stream(stream)
  assert_eq(frames.length(), 1)
  assert_eq(findings.length(), 0)
  let (errors, warnings) = count_findings(findings)
  assert_eq(errors, 0)
  assert_eq(warnings, 0)
}

///|
test "validate_stream: semantic finding on a short read reply" {
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  // A normal read-data reply (0x91) with only 2 DATA bytes: framed
  // correctly but semantically invalid (a reply needs >= 4 DI bytes).
  let stream = encode_frame(addr, 0x91, [0x00, 0x01])
  let (frames, findings) = validate_stream(stream)
  assert_eq(frames.length(), 1)
  let short = findings.filter(fn(f) { f.code == "short_read_reply" }).length()
  assert_eq(short, 1)
  let (errors, _warnings) = count_findings(findings)
  assert_eq(errors, 1)
}

///|
test "validate_stream: framing and semantic findings are both reported" {
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let bad = encode_frame(addr, 0x11, [0x00, 0x00, 0x01, 0x00])
  bad[10] = 0xFF
  let stream : Array[Byte] = [0x55]
  for b in bad {
    stream.push(b)
  }
  let (_frames, findings) = validate_stream(stream)
  let codes = findings.map(fn(f) { f.code })
  assert_true(codes.contains("stray_byte"))
  assert_true(codes.contains("bad_checksum"))
}

///|
test "validate_stream: undefined function code is flagged" {
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let stream = encode_frame(addr, 0x03, [0x00, 0x00, 0x01, 0x00])
  let (_frames, findings) = validate_stream(stream)
  let codes = findings.map(fn(f) { f.code })
  assert_true(codes.contains("unknown_function"))
}

///|
test "validate_stream: render_findings is stable for empty input" {
  assert_eq(render_findings([]), "OK: no findings\n")
}

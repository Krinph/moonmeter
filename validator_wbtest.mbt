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

///|
// Regression: a stray byte must be shown as a two-digit hex byte value,
// never as decimal Unicode code points (0x15 -> "15", not "4953").
test "validate_stream: stray byte message shows correct two-digit hex" {
  let stream : Array[Byte] = [0x15]
  let (_frames, findings) = validate_stream(stream)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].code, "stray_byte")
  assert_eq(findings[0].message, "byte 0x15 outside a frame")
}

///|
test "validate_stream: wildcard AA address is legal, not bad BCD" {
  let (_frames, findings) = validate_stream(build_read_address_request())
  let (errors, warnings) = count_findings(findings)
  assert_eq(errors, 0)
  assert_eq(warnings, 0)
}

///|
test "validate_stream: abnormal reply must carry one error byte" {
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let stream = encode_frame(addr, abnormal_reply(Command::ReadData.value()), [
    0x04, 0x05,
  ])
  let (_frames, findings) = validate_stream(stream)
  assert_true(findings.map(fn(f) { f.code }).contains("bad_error_reply_length"))
}

///|
test "validate_stream: reply data lengths are checked by function" {
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let bad_address = encode_frame(
    addr,
    normal_reply(Command::ReadAddress.value()),
    [0x00, 0x01],
  )
  let bad_next = encode_frame(addr, read_next_reply(false), [
    0x00, 0x01, 0x01, 0x02, 0x49,
  ])
  let (_f1, findings1) = validate_stream(bad_address)
  let (_f2, findings2) = validate_stream(bad_next)
  assert_true(
    findings1.map(fn(f) { f.code }).contains("bad_address_reply_length"),
  )
  assert_true(findings2.map(fn(f) { f.code }).contains("short_read_next_reply"))
}

///|
test "validate_stream: broadcast time sync has no reply" {
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let stream = encode_frame(
    addr,
    normal_reply(Command::BroadcastTimeSync.value()),
    [],
  )
  let (_frames, findings) = validate_stream(stream)
  assert_true(
    findings.map(fn(f) { f.code }).contains("unexpected_time_sync_reply"),
  )
}

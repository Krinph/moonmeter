///|
/// Tests for DL/T 645-2007 control codes, golden frames and hex helpers.

///|
test "function codes match the DL/T 645-2007 standard table" {
  assert_eq(Command::BroadcastTimeSync.value(), 0x08)
  assert_eq(Command::ReadData.value(), 0x11)
  assert_eq(Command::ReadNextData.value(), 0x12)
  assert_eq(Command::ReadAddress.value(), 0x13)
  assert_eq(Command::WriteData.value(), 0x14)
  assert_eq(Command::WriteAddress.value(), 0x15)
  assert_eq(Command::Freeze.value(), 0x16)
  assert_eq(Command::ChangeBaudRate.value(), 0x17)
  assert_eq(Command::ChangePassword.value(), 0x18)
  assert_eq(Command::ClearMaxDemand.value(), 0x19)
  assert_eq(Command::ClearMeter.value(), 0x1A)
  assert_eq(Command::ClearEvents.value(), 0x1B)
}

///|
test "control codes: normal and abnormal reply bits" {
  // 0x11 master -> 0x91 normal reply -> 0xD1 abnormal reply.
  assert_eq(normal_reply_control(Command::ReadData.value()), 0x91)
  assert_eq(abnormal_reply_control(Command::ReadData.value()), 0xD1)
  assert_true(!is_reply(0x11))
  assert_true(is_reply(0x91))
  assert_true(!is_error_reply(0x91))
  assert_true(is_error_reply(0xD1))
  // A master command with D6 set is not a valid abnormal reply.
  assert_true(!is_error_reply(0x51))
  assert_true(!has_follow_up(0x91))
  assert_true(has_follow_up(0xB1))
  assert_eq(Command::from_byte(0x11).unwrap().value(), 0x11)
  assert_eq(Command::from_byte(0x91).unwrap().value(), 0x11)
  assert_eq(Command::from_byte(0xD1).unwrap().value(), 0x11)
}

///|
test "golden: standard read request frame matches byte for byte" {
  // Address 123456789012 -> A0..A5 = 12 90 78 56 34 12.
  // DI 00010000 -> wire 00 00 01 00 -> +0x33 = 33 33 34 33.
  let addr = hex_decode("12 90 78 56 34 12").unwrap()
  let req = build_read_request(addr, di_active_total())
  assert_eq(hex_encode(req), "68 12 90 78 56 34 12 68 11 04 33 33 34 33 68 16")
  let frame = decode_frame(req).unwrap()
  assert_eq(frame.control, 0x11)
  assert_eq(frame.data.length(), 4)
  // Logical DI bytes restored: DI0..DI3 = 00 00 01 00.
  assert_eq(frame.data[0], 0x00)
  assert_eq(frame.data[1], 0x00)
  assert_eq(frame.data[2], 0x01)
  assert_eq(frame.data[3], 0x00)
}

///|
test "golden: standard read reply decodes to 1234.56 kWh" {
  let reply = hex_decode(
    "68 12 90 78 56 34 12 68 91 08 33 33 34 33 89 67 45 33 54 16",
  ).unwrap()
  assert_eq(reply.length(), 20)
  let frame = decode_frame(reply).unwrap()
  assert_eq(frame.control, 0x91)
  assert_eq(frame.data.length(), 8)
  // DATA de-offset: DI 00 00 01 00, value 56 34 12 00.
  assert_eq(frame.data[0], 0x00)
  assert_eq(frame.data[1], 0x00)
  assert_eq(frame.data[2], 0x01)
  assert_eq(frame.data[3], 0x00)
  let reading = parse_reading(frame.data).unwrap()
  assert_eq(reading.di.to_string(), "00010000")
  assert_eq(di_label(reading.di), "Forward active total energy")
  let info = di_info(reading.di).unwrap()
  let (raw, decimals) = decode_energy(reading.value, info.decimals)
  assert_eq(raw, 123456)
  assert_eq(decimals, 2)
  assert_eq(format_energy(raw, decimals), "1234.56")
}

///|
test "hex: decode and encode round-trip" {
  let bytes = hex_decode("68 12 90 78 56 34 12 68 11 04 33 33 34 33 68 16").unwrap()
  assert_eq(bytes.length(), 16)
  assert_eq(bytes[0], 0x68)
  assert_eq(bytes[15], 0x16)
  assert_eq(
    hex_encode(bytes),
    "68 12 90 78 56 34 12 68 11 04 33 33 34 33 68 16",
  )
  assert_eq(hex_decode("68000102030405").unwrap().length(), 7)
  assert_true(hex_decode("xyz") is None)
  assert_true(hex_decode("123") is None)
}

///|
test "hex: lowercase and comma separators accepted" {
  let b = hex_decode("68,12,90,78,56,34,12,68,11,04,33,33,34,33,68,16").unwrap()
  assert_eq(b.length(), 16)
  assert_eq(b[0], 0x68)
}

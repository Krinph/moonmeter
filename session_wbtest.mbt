///|
/// Golden frame tests for the full DL/T 645-2007 application-layer command
/// set and multi-frame interaction semantics.

///|
test "reply control bytes: normal 9x, follow-up Bx, abnormal Dx" {
  assert_eq(normal_reply(Command::ReadData.value()), 0x91)
  assert_eq(follow_up_reply(Command::ReadData.value()), 0xB1)
  assert_eq(abnormal_reply(Command::ReadData.value()), 0xD1)
  assert_eq(normal_reply(Command::WriteData.value()), 0x94)
  assert_eq(abnormal_reply(Command::WriteData.value()), 0xD4)
  assert_eq(read_next_reply(false), 0x92)
  assert_eq(read_next_reply(true), 0xB2)
  assert_eq(reply_control(Command::ReadData.value(), true, true), 0xF1)
}

///|
test "golden: read next data request with frame sequence 1" {
  let addr = hex_decode("18 35 00 10 02 10").unwrap()
  let req = build_read_next_request(addr, di_voltage(), 0x01)
  assert_eq(
    hex_encode(req),
    "68 18 35 00 10 02 10 68 12 05 33 34 34 35 34 5A 16",
  )
  let frame = decode_frame(req).unwrap()
  assert_eq(frame.data.length(), 5)
  assert_eq(frame.data[4], 0x01)
}

///|
test "golden: read next data reply decodes value and sequence" {
  let reply = hex_decode(
    "68 18 35 00 10 02 10 68 92 07 33 34 34 35 7C 55 34 AD 16",
  ).unwrap()
  let frame = decode_frame(reply).unwrap()
  assert_eq(frame.control, 0x92)
  let reading = parse_next_reading(frame.data).unwrap()
  assert_eq(reading.di.to_string(), "02010100")
  assert_eq(reading.seq, 0x01)
  assert_eq(bcd_decode(reading.value), 2249)
}

///|
test "golden: read address request uses wildcard address" {
  let req = build_read_address_request()
  assert_eq(hex_encode(req), "68 AA AA AA AA AA AA 68 13 00 DF 16")
}

///|
test "golden: broadcast time sync transmits time low byte first" {
  let req = build_time_sync(broadcast_address(), 211229, 170530)
  assert_eq(
    hex_encode(req),
    "68 99 99 99 99 99 99 68 08 06 63 38 4A 5C 45 54 4E 16",
  )
}

///|
test "golden: freeze request fields low byte first" {
  let addr = hex_decode("18 35 00 10 02 10").unwrap()
  let req = build_freeze_request(addr, 12, 29, 17, 5)
  assert_eq(hex_encode(req), "68 18 35 00 10 02 10 68 16 04 38 4A 5C 45 7C 16")
}

///|
test "golden: change baud rate request and echoed reply" {
  let addr = hex_decode("18 35 00 10 02 10").unwrap()
  let req = build_change_baud_request(addr, 0x20)
  assert_eq(hex_encode(req), "68 18 35 00 10 02 10 68 17 01 53 AA 16")
  assert_eq(read_next_reply(false), 0x92)
  let reply_ctrl = normal_reply(Command::ChangeBaudRate.value())
  assert_eq(reply_ctrl, 0x97)
}

///|
test "write data request carries DI, password, operator and value" {
  let addr = hex_decode("18 35 00 10 02 10").unwrap()
  let password : Array[Byte] = [0x00, 0x90, 0x78, 0x56]
  let operator : Array[Byte] = [0x02, 0x01, 0x01, 0x00]
  let value : Array[Byte] = [0x05, 0x17, 0x29, 0x12, 0x21]
  let req = build_write_data_request(
    addr,
    di_active_total(),
    password,
    operator,
    value,
  )
  let frame = decode_frame(req).unwrap()
  assert_eq(frame.control, 0x14)
  assert_eq(frame.data.length(), 17)
  assert_eq(normal_reply(Command::WriteData.value()), 0x94)
}

///|
test "clear commands build requests with password and operator code" {
  let addr = hex_decode("18 35 00 10 02 10").unwrap()
  let password : Array[Byte] = [0x00, 0x90, 0x78, 0x56]
  let operator : Array[Byte] = [0x02, 0x01, 0x01, 0x00]
  let clear_demand = build_clear_max_demand_request(addr, password, operator)
  let clear_meter = build_clear_meter_request(addr, password, operator)
  let clear_events = build_clear_events_request(
    addr,
    password,
    operator,
    di_voltage(),
  )
  assert_eq(decode_frame(clear_demand).unwrap().data.length(), 8)
  assert_eq(decode_frame(clear_meter).unwrap().data.length(), 8)
  assert_eq(decode_frame(clear_events).unwrap().data.length(), 12)
  assert_eq(normal_reply(Command::ClearMaxDemand.value()), 0x99)
  assert_eq(normal_reply(Command::ClearMeter.value()), 0x9A)
  assert_eq(normal_reply(Command::ClearEvents.value()), 0x9B)
}

///|
test "write address request uses wildcard and +33-encoded address" {
  let new_addr = hex_decode("18 35 00 10 02 10").unwrap()
  let req = build_write_address_request(new_addr)
  // DATA is offset by +0x33: 18 35 00 10 02 10 -> 4B 68 33 43 35 43.
  // (Some tutorials omit this offset; the standard requires it for all DATA.)
  assert_eq(
    hex_encode(req),
    "68 AA AA AA AA AA AA 68 15 06 4B 68 33 43 35 43 88 16",
  )
}

///|
test "describe_reply captures full interaction state" {
  // Abnormal read reply: logical DATA = 0x04 (data length error).
  let addr = hex_decode("12 90 78 56 34 12").unwrap()
  let reply = encode_frame(addr, abnormal_reply(Command::ReadData.value()), [
    0x04,
  ])
  let frame = decode_frame(reply).unwrap()
  let info = describe_reply(frame)
  assert_eq(info.control, 0xD1)
  assert_true(info.abnormal)
  assert_true(!info.follow_up)
  match info.command {
    Some(c) => assert_eq(c.value(), Command::ReadData.value())
    None => assert_true(false)
  }
  match info.error {
    Some(e) => assert_eq(e.label(), "data length error")
    None => assert_true(false)
  }
}

///|
test "sequence numbers must match between request and reply" {
  let addr = hex_decode("18 35 00 10 02 10").unwrap()
  let req = build_read_next_request(addr, di_voltage(), 0x01)
  let reply_ok = encode_frame(addr, read_next_reply(false), [
    0x00, 0x01, 0x01, 0x02, 0x49, 0x22, 0x01,
  ])
  let reply_bad = encode_frame(addr, read_next_reply(false), [
    0x00, 0x01, 0x01, 0x02, 0x49, 0x22, 0x02,
  ])
  assert_true(sequence_matches(req, reply_ok))
  assert_true(!sequence_matches(req, reply_bad))
}

///|
test "sequence matching rejects unrelated function codes and mismatched DI" {
  let addr = hex_decode("18 35 00 10 02 10").unwrap()
  let req = build_read_next_request(addr, di_voltage(), 0x01)
  // A read-data command with the same trailing byte is not a read-next pair.
  let wrong_function = encode_frame(addr, Command::ReadData.value(), [
    0x00, 0x01, 0x01, 0x02, 0x01,
  ])
  assert_true(!sequence_matches(req, wrong_function))
  // A read-next reply for a different DI must not be accepted either.
  let wrong_di = encode_frame(addr, read_next_reply(false), [
    0x00, 0x01, 0x01, 0x03, 0x49, 0x22, 0x01,
  ])
  assert_true(!sequence_matches(req, wrong_di))
  // An abnormal reply is not a valid sequence continuation.
  let abnormal = encode_frame(
    addr,
    abnormal_reply(Command::ReadNextData.value()),
    [0x04],
  )
  assert_true(!sequence_matches(req, abnormal))
}

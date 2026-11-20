///|
/// White-box tests for energy decoding and display formatting.

///|
test "energy: decode raw BCD value with decimals" {
  let (raw, decimals) = decode_energy([0x56, 0x34, 0x12, 0x00], 2)
  assert_eq(raw, 123456)
  assert_eq(decimals, 2)
}

///|
test "energy: format fixed-point decimal values" {
  assert_eq(format_energy(123456, 2), "1234.56")
  assert_eq(format_energy(1234, 3), "1.234")
  assert_eq(format_energy(5, 1), "0.5")
  assert_eq(format_energy(42, 0), "42")
}

///|
test "energy: leading zeros are preserved for the fractional part" {
  assert_eq(format_energy(100005, 3), "100.005")
  assert_eq(format_energy(100, 4), "0.0100")
}

///|
test "energy: end-to-end read -> decode -> format" {
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let sim = MeterSim::new(addr)
  sim.set_reading(di_active_total(), [0x56, 0x34, 0x12, 0x00])
  let req = build_read_request(addr, di_active_total())
  let reply = sim.answer_read(req).unwrap()
  let frame = decode_frame(reply).unwrap()
  let reading = parse_reading(frame.data).unwrap()
  let (raw, decimals) = decode_energy(reading.value, 2)
  assert_eq(format_energy(raw, decimals), "1234.56")
}

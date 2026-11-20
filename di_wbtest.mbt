///|
/// White-box tests for the data-identifier catalog.

///|
test "di catalog: energy identifiers carry kWh metadata" {
  let cases : Array[(DataId, String)] = [
    (di_active_total(), "Total active energy"),
    (di_active_peak(), "Peak active energy"),
    (di_active_flat(), "Flat active energy"),
    (di_active_peak2(), "Peak-2 active energy"),
    (di_active_valley(), "Valley active energy"),
  ]
  for (di, expected) in cases {
    let info = di_info(di).unwrap()
    assert_eq(info.name, expected)
    assert_eq(info.unit, "kWh")
    assert_eq(info.decimals, 2)
  }
}

///|
test "di catalog: voltage, current and power metadata" {
  let v = di_info(di_voltage()).unwrap()
  assert_eq(v.name, "Voltage")
  assert_eq(v.unit, "V")
  let c = di_info(di_current()).unwrap()
  assert_eq(c.name, "Current")
  assert_eq(c.unit, "A")
  let p = di_info(di_power()).unwrap()
  assert_eq(p.name, "Power")
  assert_eq(p.unit, "kW")
}

///|
test "di catalog: unknown identifier is reported, not guessed" {
  assert_true(di_info(DataId::new(9, 9, 9, 9)) is None)
  assert_eq(di_label(DataId::new(9, 9, 9, 9)), "DI 09090909")
  assert_eq(di_label(di_active_total()), "Total active energy")
}

///|
/// The reply frame quoted in README.md and used by the CI smoke test must
/// stay decodable; otherwise the documented `parse` example silently breaks.
test "di catalog: documented example frame stays valid" {
  let frame_hex = "68 00 01 02 03 04 05 68 81 08 00 00 00 00 00 56 34 12 00 04 16"
  let bytes = hex_decode(frame_hex).unwrap()
  assert_eq(bytes.length(), 21)
  let frame = decode_frame(bytes).unwrap()
  let reading = parse_reading(frame.data).unwrap()
  assert_eq(di_label(reading.di), "Total active energy")
  assert_eq(bcd_decode(reading.value), 123456)
}

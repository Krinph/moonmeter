///|
/// White-box tests for the DL/T 645-2007 data-identifier catalog.

///|
test "di catalog: identifiers use standard DI3DI2DI1DI0 notation" {
  assert_eq(di_active_total().to_string(), "00010000")
  assert_eq(di_active_peak().to_string(), "00010100")
  assert_eq(di_active_flat().to_string(), "00010200")
  assert_eq(di_active_peak2().to_string(), "00010300")
  assert_eq(di_active_valley().to_string(), "00010400")
  assert_eq(di_voltage().to_string(), "02010100")
  assert_eq(di_current().to_string(), "02020100")
  assert_eq(di_power().to_string(), "02030000")
}

///|
test "di catalog: energy identifiers carry kWh metadata" {
  let cases : Array[(DataId, String)] = [
    (di_active_total(), "Forward active total energy"),
    (di_active_peak(), "Forward active peak energy"),
    (di_active_flat(), "Forward active flat energy"),
    (di_active_peak2(), "Forward active shoulder energy"),
    (di_active_valley(), "Forward active valley energy"),
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
  assert_eq(v.name, "Phase A voltage")
  assert_eq(v.unit, "V")
  assert_eq(v.decimals, 1)
  let c = di_info(di_current()).unwrap()
  assert_eq(c.unit, "A")
  assert_eq(c.decimals, 3)
  let p = di_info(di_power()).unwrap()
  assert_eq(p.unit, "kW")
  assert_eq(p.decimals, 2)
}

///|
test "di catalog: unknown identifier is reported, not guessed" {
  assert_true(di_info(DataId::new(9, 9, 9, 9)) is None)
  assert_eq(di_label(DataId::new(9, 9, 9, 9)), "DI 09090909")
  assert_eq(di_label(di_active_total()), "Forward active total energy")
}

///|
test "di catalog: wire order is DI0,DI1,DI2,DI3" {
  let wire = di_active_total().wire_bytes()
  assert_eq(wire[0], 0x00)
  assert_eq(wire[1], 0x00)
  assert_eq(wire[2], 0x01)
  assert_eq(wire[3], 0x00)
  let vwire = di_voltage().wire_bytes()
  assert_eq(vwire[0], 0x00)
  assert_eq(vwire[1], 0x01)
  assert_eq(vwire[2], 0x01)
  assert_eq(vwire[3], 0x02)
}

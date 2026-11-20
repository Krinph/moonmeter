///|
/// White-box tests for meter address validation and digit conversion.

///|
test "address: valid 6-byte BCD address accepted" {
  assert_true(valid_address([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]))
  assert_true(valid_address([0x99, 0x99, 0x99, 0x99, 0x99, 0x99]))
}

///|
test "address: wrong length and bad BCD rejected" {
  assert_true(!valid_address([0x00, 0x01]))
  assert_true(!valid_address([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]))
  assert_true(!valid_address([0x0A, 0x01, 0x02, 0x03, 0x04, 0x05]))
  assert_true(!valid_address([0x00, 0xF1, 0x02, 0x03, 0x04, 0x05]))
}

///|
test "address: digits round-trip (low byte first)" {
  let bytes = address_from_digits("000102030405").unwrap()
  assert_eq(bytes.length(), 6)
  // "05" is the least-significant pair, so it is the first (low) byte.
  assert_eq(bytes[0], 0x05)
  assert_eq(bytes[5], 0x00)
  assert_eq(address_to_digits(bytes).unwrap(), "000102030405")
}

///|
test "address: malformed digit strings rejected" {
  assert_true(address_from_digits("12345") is None)
  assert_true(address_from_digits("00010203040A") is None)
  assert_true(address_to_digits([0x0A, 0x01, 0x02, 0x03, 0x04, 0x05]) is None)
}

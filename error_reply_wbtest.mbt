///|
/// White-box tests for DL/T 645-2007 abnormal-reply decoding.

///|
test "error codes: all standard bytes decode" {
  assert_true(ErrorCode::from_byte(0x01) is PasswordError)
  assert_true(ErrorCode::from_byte(0x02) is ControlCodeError)
  assert_true(ErrorCode::from_byte(0x03) is DataIdError)
  assert_true(ErrorCode::from_byte(0x04) is DataLengthError)
  assert_true(ErrorCode::from_byte(0x05) is AddressError)
  assert_true(ErrorCode::from_byte(0x06) is OtherError)
  assert_true(ErrorCode::from_byte(0xFF) is Unknown)
}

///|
test "error codes: labels are human readable" {
  assert_eq(ErrorCode::from_byte(0x01).label(), "password error")
  assert_eq(ErrorCode::from_byte(0x05).label(), "address error")
  assert_eq(ErrorCode::from_byte(0xFF).label(), "unknown error code")
}

///|
test "error reply: decoded from a 0xD1 abnormal reply frame" {
  // 0xD1 = slave reply(0x80) + abnormal(0x40) + read-data function(0x11).
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let control = abnormal_reply_control(Command::ReadData.value())
  assert_eq(control, 0xD1)
  let frame_bytes = encode_frame(addr, control, [0x02])
  let frame = decode_frame(frame_bytes).unwrap()
  assert_true(is_error_reply(frame.control))
  let code = decode_error_reply(frame).unwrap()
  assert_true(code is ControlCodeError)
  assert_eq(code.label(), "control code error")
}

///|
test "error reply: normal reply and empty data yield no error code" {
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let ok = decode_frame(
    encode_frame(addr, normal_reply_control(Command::ReadData.value()), [
      0x00, 0x00, 0x01, 0x00,
    ]),
  ).unwrap()
  assert_true(decode_error_reply(ok) is None)
  let empty_err = decode_frame(encode_frame(addr, 0xD1, [])).unwrap()
  assert_true(decode_error_reply(empty_err) is None)
}

///|
test "error reply: 0xC1 is not treated as a standard abnormal reply" {
  // 0xC1 has D7+D6 set but function code 0x01, which is not a defined
  // DL/T 645-2007 function; the standard abnormal read reply is 0xD1.
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let frame = decode_frame(encode_frame(addr, 0xC1, [0x02])).unwrap()
  // Bits D7+D6 are set, so the flag helper reports abnormal; but the
  // function code 0x01 is undefined, which the validator flags separately.
  assert_true(is_error_reply(frame.control))
  assert_true(Command::from_byte(frame.control) is None)
}

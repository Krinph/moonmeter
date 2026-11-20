///|
/// White-box tests for DL/T 645 error-reply decoding.

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
test "error reply: decoded from a real frame" {
  // 0xC1 = reply(0x80) + error(0x40) + read-data function(0x01).
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let frame_bytes = encode_frame(addr, 0xC1, [0x02, 0x00, 0x00, 0x00])
  let frame = decode_frame(frame_bytes).unwrap()
  assert_true(is_error_reply(frame.control))
  let code = decode_error_reply(frame).unwrap()
  assert_true(code is ControlCodeError)
  assert_eq(code.label(), "control code error")
}

///|
test "error reply: normal reply and empty data yield no error code" {
  let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let ok = decode_frame(encode_frame(addr, 0x81, [0x00, 0x00, 0x00, 0x00])).unwrap()
  assert_true(decode_error_reply(ok) is None)
  let empty_err = decode_frame(encode_frame(addr, 0xC1, [])).unwrap()
  assert_true(decode_error_reply(empty_err) is None)
}

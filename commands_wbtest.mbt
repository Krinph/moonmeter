///|
/// Tests for all DL/T 645 control codes and the hex helpers.

///|
test "all command codes map to their spec bytes" {
  assert_eq(Command::ReadData.value(), 0x01)
  assert_eq(Command::ReadNextData.value(), 0x02)
  assert_eq(Command::WriteDataMulti.value(), 0x03)
  assert_eq(Command::WriteAddress.value(), 0x04)
  assert_eq(Command::BroadcastTimeSync.value(), 0x05)
  assert_eq(Command::WriteDataSingle.value(), 0x06)
  assert_eq(Command::ReadAddress.value(), 0x07)
  assert_eq(Command::ChangePassword.value(), 0x08)
  assert_eq(Command::ClearMaxDemand.value(), 0x09)
  assert_eq(Command::ClearMeter.value(), 0x0A)
  assert_eq(Command::ClearEvents.value(), 0x0B)
  assert_eq(Command::ReadBlocks.value(), 0x0C)
  assert_eq(Command::ReadEvents.value(), 0x0D)
  assert_eq(Command::Freeze.value(), 0x0E)
  assert_eq(Command::ReadVersion.value(), 0x0F)
}

///|
test "hex: decode and encode round-trip" {
  let bytes = hex_decode("68 00 01 02 03 04 05 68 01 04 00 00 00 00 00 E4 16").unwrap()
  assert_eq(bytes.length(), 17)
  assert_eq(bytes[0], 0x68)
  assert_eq(bytes[16], 0x16)
  assert_eq(
    hex_encode(bytes),
    "68 00 01 02 03 04 05 68 01 04 00 00 00 00 00 E4 16",
  )
  assert_eq(hex_decode("68000102030405").unwrap().length(), 7)
  assert_true(hex_decode("xyz") is None)
  assert_true(hex_decode("123") is None)
}

///|
test "hex: lowercase and comma separators accepted" {
  let b = hex_decode("68,00,01,02,03,04,05,68,01,04,00,00,00,00,00,e4,16").unwrap()
  assert_eq(b[15], 0xE4)
  assert_eq(b.length(), 17)
}

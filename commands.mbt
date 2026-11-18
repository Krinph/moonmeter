///|
/// High-level DL/T 645 command builders and responses.
///
/// A "read data" request sends control 0x01 with a 4-byte data field holding
/// DI0..DI3. The meter answers with control 0x81 and the requested values
/// appended after the DI bytes.

///|
/// A structured reading: the DI that was read plus the decoded value bytes.
pub struct Reading {
  di : DataId
  /// Raw value bytes (after the 4 DI bytes in the reply data field).
  value : Array[Byte]
}

///|
/// Build a "read data" request frame (control 0x01).
pub fn build_read_request(address : Array[Byte], di : DataId) -> Array[Byte] {
  let data : Array[Byte] = []
  data.push(di.di0.to_byte())
  data.push(di.di1.to_byte())
  data.push(di.di2.to_byte())
  data.push(di.di3.to_byte())
  encode_frame(address, Command::ReadData.value(), data)
}

///|
/// Build a broadcast time-sync frame (control 0x05, address all-0xFF).
/// The data field is the 6-byte BCD time: YY MM DD hh mm ss.
pub fn build_time_sync(
  address : Array[Byte],
  yymmdd : Int32,
  hhmmss : Int32,
) -> Array[Byte] {
  let data : Array[Byte] = []
  data.push(bcd_from(yymmdd / 10000 % 100))
  data.push(bcd_from(yymmdd / 100 % 100))
  data.push(bcd_from(yymmdd % 100))
  data.push(bcd_from(hhmmss / 10000 % 100))
  data.push(bcd_from(hhmmss / 100 % 100))
  data.push(bcd_from(hhmmss % 100))
  encode_frame(address, Command::BroadcastTimeSync.value(), data)
}

///|
/// Parse a reply data field: the first 4 bytes are DI0..DI3, the rest is the
/// value. Returns `None` if the field is too short.
pub fn parse_reading(data : Array[Byte]) -> Reading? {
  if data.length() < 4 {
    return None
  }
  let value : Array[Byte] = []
  for i = 4; i < data.length(); i = i + 1 {
    value.push(data[i])
  }
  Some({
    di: DataId::new(
      data[0].to_int(),
      data[1].to_int(),
      data[2].to_int(),
      data[3].to_int(),
    ),
    value,
  })
}

///|
/// Decode an active-energy reading: `value` holds 4 BCD bytes representing
/// `XXX.X` kWh (2 decimal digits shown as 1, i.e. value / 10.0).
/// Returns the raw integer (in 0.1 kWh units) and the number of decimals.
pub fn decode_energy(value : Array[Byte], decimals : Int32) -> (Int32, Int32) {
  let raw = bcd_decode(value)
  (raw, decimals)
}

///|
/// Helper: does a reply carry the "slave replies" direction bit?
pub fn is_reply(control : Byte) -> Bool {
  (control.to_int() & 0x80) != 0
}

///|
/// Is this an error reply (bit 6 set)?
pub fn is_error_reply(control : Byte) -> Bool {
  (control.to_int() & 0x40) != 0
}

///|
/// The function code part of a control byte (bits 4..0).
pub fn function_code(control : Byte) -> Int32 {
  control.to_int() & 0x1F
}

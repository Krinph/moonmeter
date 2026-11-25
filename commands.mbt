///|
/// High-level DL/T 645-2007 command builders and responses.
///
/// A read-data request sends control 0x11 with a 4-byte DATA field holding
/// the data identifier in wire order DI0..DI3 (offset by +0x33 on the wire).
/// The meter answers with control 0x91 (normal) or 0xD1 (abnormal), carrying
/// the DI echo plus the requested value bytes.

///|
/// A structured reading: the DI that was read plus the decoded value bytes.
pub struct Reading {
  di : DataId
  /// Logical value bytes (after the 4 DI bytes in the reply DATA field).
  value : Array[Byte]
}

///|
/// Build a "read data" request frame (control 0x11).
pub fn build_read_request(address : Array[Byte], di : DataId) -> Array[Byte] {
  encode_frame(address, Command::ReadData.value(), di.wire_bytes())
}

///|
/// Build a broadcast time-sync frame. DL/T 645-2007 defines broadcast
/// time sync with control 0x08 and the broadcast address all-0x99 (the
/// 12-digit address 999999999999H). The DATA field is 6 BCD bytes
/// YY MM DD hh mm ss. Per the standard a broadcast command gets no reply.
pub fn build_time_sync(
  address : Array[Byte],
  yymmdd : Int32,
  hhmmss : Int32,
) -> Array[Byte] {
  let data : Array[Byte] = []
  // Per the standard, time is transmitted low byte first (SS MM HH DD MM YY).
  // Example: 21-12-29 17:05:30 -> 30 05 17 29 12 21 before +0x33.
  data.push(bcd_from(hhmmss % 100))
  data.push(bcd_from(hhmmss / 100 % 100))
  data.push(bcd_from(hhmmss / 10000 % 100))
  data.push(bcd_from(yymmdd % 100))
  data.push(bcd_from(yymmdd / 100 % 100))
  data.push(bcd_from(yymmdd / 10000 % 100))
  encode_frame(address, Command::BroadcastTimeSync.value(), data)
}

///|
/// Parse a reply DATA field: the first 4 logical bytes are DI0..DI3 (wire
/// order), the rest is the value. Returns `None` if too short.
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
      data[3].to_int(),
      data[2].to_int(),
      data[1].to_int(),
      data[0].to_int(),
    ),
    value,
  })
}

///|
/// Decode an active-energy reading: `value` holds BCD bytes representing
/// energy in kWh. Returns the raw integer and the number of decimals, so
/// `format_energy` can turn it into a display value. For the common
/// 4-byte register the value is in 0.01 kWh units (2 decimals).
pub fn decode_energy(value : Array[Byte], decimals : Int32) -> (Int32, Int32) {
  (bcd_decode(value), decimals)
}

///|
/// Format a decoded energy reading as a fixed-point decimal string.
/// `(123456, 2)` becomes "1234.56" kWh.
pub fn format_energy(raw : Int32, decimals : Int32) -> String {
  if decimals <= 0 {
    return raw.to_string()
  }
  let mut scale = 1
  for _i = 0; _i < decimals; _i = _i + 1 {
    scale = scale * 10
  }
  let whole = raw / scale
  let frac = raw % scale
  let mut frac_str = frac.to_string()
  while frac_str.length() < decimals {
    frac_str = "0" + frac_str
  }
  whole.to_string() + "." + frac_str
}

///|
/// Is the control byte a slave reply? D7 set.
pub fn is_reply(control : Byte) -> Bool {
  (control.to_int() & ControlDirection) != 0
}

///|
/// Is the control byte an abnormal (error) reply? D7 AND D6 set.
/// A master command with D6 set is not a valid abnormal reply.
pub fn is_error_reply(control : Byte) -> Bool {
  let c = control.to_int()
  (c & ControlDirection) != 0 && (c & ControlAbnormal) != 0
}

///|
/// Does the control byte indicate a follow-up frame? D5 set.
pub fn has_follow_up(control : Byte) -> Bool {
  (control.to_int() & ControlFollowUp) != 0
}

///|
/// The function code part of a control byte (D4..D0).
pub fn function_code(control : Byte) -> Int32 {
  control.to_int() & ControlFunctionMask
}

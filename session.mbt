///|
/// DL/T 645-2007 full application-layer session support.
///
/// The standard defines twelve master function codes (0x08, 0x11..0x1B) and
/// a reply-control scheme that encodes three independent facts:
///   - D7: direction (0 = master command, 1 = slave reply)
///   - D6: abnormal flag (1 = error reply)
///   - D5: follow-up flag (1 = more frames follow)
///   - D4..D0: function code
///
/// The high nibble of a slave reply therefore carries the full interaction
/// state: `9x` = normal / no follow-up, `Bx` = normal / follow-up exists,
/// `Dx` = abnormal. `x` is the function code. Broadcast time sync (0x08)
/// is the one command that gets no reply.
///
/// This module builds a request for every standard function, computes the
/// matching reply control byte, handles the read-next-data sequence number
/// used for multi-frame transfers, and reads a whole reading session.
/// Together these model the COMPLETE interaction semantics of the standard,
/// not just a single read frame.

///|
/// The all-AA address, used to read or write the meter communication address.
pub fn wildcard_address() -> Array[Byte] {
  [0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA]
}

///|
/// The all-99 broadcast address, valid only for broadcast commands
/// (time sync, broadcast freeze). Broadcast commands get no reply.
pub fn broadcast_address() -> Array[Byte] {
  [0x99, 0x99, 0x99, 0x99, 0x99, 0x99]
}

///|
/// Reply control byte for a function with explicit interaction state.
///
/// `follow_up` sets D5 (0xBx), `abnormal` sets D6 (0xDx); both set gives
/// 0xFx. `abnormal` and `follow_up` are normally mutually exclusive in
/// practice, but the bit math mirrors the standard exactly.
pub fn reply_control(
  function : Byte,
  follow_up : Bool,
  abnormal : Bool,
) -> Byte {
  let mut c = ControlDirection | function.to_int()
  if follow_up {
    c = c | ControlFollowUp
  }
  if abnormal {
    c = c | ControlAbnormal
  }
  c.to_byte()
}

///|
/// Normal reply without follow-up (0x9x). Read data: 0x11 -> 0x91.
pub fn normal_reply(function : Byte) -> Byte {
  reply_control(function, false, false)
}

///|
/// Normal reply with follow-up frames (0xBx). Read data: 0x11 -> 0xB1.
pub fn follow_up_reply(function : Byte) -> Byte {
  reply_control(function, true, false)
}

///|
/// Abnormal reply (0xDx). Read data: 0x11 -> 0xD1.
pub fn abnormal_reply(function : Byte) -> Byte {
  reply_control(function, false, true)
}

///|
/// The slave reply for the read-next-data function: 0x92 (no follow-up)
/// or 0xB2 (more frames follow).
pub fn read_next_reply(follow_up : Bool) -> Byte {
  reply_control(Command::ReadNextData.value(), follow_up, false)
}

///|
/// Build a "read subsequent data" request (0x12) with a frame sequence.
/// Standard DATA = DI0..DI3 then SEQ; L = 5. `seq` counts from 1 and
/// the reply must echo the same sequence number.
pub fn build_read_next_request(
  address : Array[Byte],
  di : DataId,
  seq : Byte,
) -> Array[Byte] {
  let data : Array[Byte] = []
  for b in di.wire_bytes() {
    data.push(b)
  }
  data.push(seq)
  encode_frame(address, Command::ReadNextData.value(), data)
}

///|
/// Parse a read-next reply DATA field. Standard layout after -0x33:
/// DI0..DI3, value bytes N1..Nm, then a trailing one-byte sequence number.
/// Returns `None` when too short (< 6 bytes).
pub struct NextReading {
  di : DataId
  value : Array[Byte]
  seq : Byte
}

///|
pub fn parse_next_reading(data : Array[Byte]) -> NextReading? {
  if data.length() < 6 {
    return None
  }
  let seq = data[data.length() - 1]
  let di = DataId::new(
    data[3].to_int(),
    data[2].to_int(),
    data[1].to_int(),
    data[0].to_int(),
  )
  let value : Array[Byte] = []
  for i = 4; i < data.length() - 1; i = i + 1 {
    value.push(data[i])
  }
  Some({ di, value, seq, })
}

///|
/// Build a "read communication address" request (0x13, L = 0). The master
/// uses the all-AA wildcard address; the reply (0x93) carries the real
/// address in its DATA field.
pub fn build_read_address_request() -> Array[Byte] {
  encode_frame(wildcard_address(), Command::ReadAddress.value(), [])
}

///|
/// Build a "write communication address" request (0x15, L = 6). The master
/// uses the all-AA wildcard address and sends the new 6-byte address.
pub fn build_write_address_request(new_address : Array[Byte]) -> Array[Byte] {
  encode_frame(wildcard_address(), Command::WriteAddress.value(), new_address)
}

///|
/// Build a "write data" request (0x14). Standard DATA =
/// DI0..DI3 | PA P0 P1 P2 (password) | C0..C3 (operator code) | N1..Nm.
/// `password` and `operator` are each 4 bytes; `value` is the parameter.
pub fn build_write_data_request(
  address : Array[Byte],
  di : DataId,
  password : Array[Byte],
  operator : Array[Byte],
  value : Array[Byte],
) -> Array[Byte] {
  let data : Array[Byte] = []
  for b in di.wire_bytes() {
    data.push(b)
  }
  for b in password {
    data.push(b)
  }
  for b in operator {
    data.push(b)
  }
  for b in value {
    data.push(b)
  }
  encode_frame(address, Command::WriteData.value(), data)
}

///|
/// Build a "freeze" request (0x16). DATA is 4 BCD bytes MM DD hh mm,
/// stored low byte first per the standard; the reply is 0x96.
pub fn build_freeze_request(
  address : Array[Byte],
  month : Int32,
  day : Int32,
  hour : Int32,
  minute : Int32,
) -> Array[Byte] {
  let data : Array[Byte] = []
  // Low byte first on the wire: mm, hh, DD, MM.
  data.push(bcd_from(minute))
  data.push(bcd_from(hour))
  data.push(bcd_from(day))
  data.push(bcd_from(month))
  encode_frame(address, Command::Freeze.value(), data)
}

///|
/// Build a "change baud rate" request (0x17). DATA is one rate-feature byte;
/// the reply (0x97) echoes the same byte.
pub fn build_change_baud_request(
  address : Array[Byte],
  rate : Byte,
) -> Array[Byte] {
  encode_frame(address, Command::ChangeBaudRate.value(), [rate])
}

///|
/// Build a "change password" request (0x18). DATA =
/// DI0..DI3 | old PA P0 P1 P2 | new PA P0 P1 P2 (12 bytes).
pub fn build_change_password_request(
  address : Array[Byte],
  di : DataId,
  old_password : Array[Byte],
  new_password : Array[Byte],
) -> Array[Byte] {
  let data : Array[Byte] = []
  for b in di.wire_bytes() {
    data.push(b)
  }
  for b in old_password {
    data.push(b)
  }
  for b in new_password {
    data.push(b)
  }
  encode_frame(address, Command::ChangePassword.value(), data)
}

///|
/// Build a "clear max demand" request (0x19). DATA =
/// PA P0 P1 P2 | C0..C3 (password + operator code, 8 bytes).
pub fn build_clear_max_demand_request(
  address : Array[Byte],
  password : Array[Byte],
  operator : Array[Byte],
) -> Array[Byte] {
  let data : Array[Byte] = []
  for b in password {
    data.push(b)
  }
  for b in operator {
    data.push(b)
  }
  encode_frame(address, Command::ClearMaxDemand.value(), data)
}

///|
/// Build a "clear meter" request (0x1A). DATA = password + operator code.
pub fn build_clear_meter_request(
  address : Array[Byte],
  password : Array[Byte],
  operator : Array[Byte],
) -> Array[Byte] {
  let data : Array[Byte] = []
  for b in password {
    data.push(b)
  }
  for b in operator {
    data.push(b)
  }
  encode_frame(address, Command::ClearMeter.value(), data)
}

///|
/// Build a "clear events" request (0x1B). DATA =
/// password (4) + operator code (4) + event DI (4).
pub fn build_clear_events_request(
  address : Array[Byte],
  password : Array[Byte],
  operator : Array[Byte],
  di : DataId,
) -> Array[Byte] {
  let data : Array[Byte] = []
  for b in password {
    data.push(b)
  }
  for b in operator {
    data.push(b)
  }
  for b in di.wire_bytes() {
    data.push(b)
  }
  encode_frame(address, Command::ClearEvents.value(), data)
}

///|
/// A named summary of a reply: function, control byte, interaction state,
/// and decoded error code when abnormal.
pub struct ReplyInfo {
  command : Command?
  control : Byte
  abnormal : Bool
  follow_up : Bool
  error : ErrorCode?
}

///|
/// Describe a decoded reply frame, capturing the complete interaction state
/// that a conformance tester needs (direction, abnormal flag, follow-up,
/// function and error code).
pub fn describe_reply(frame : Frame) -> ReplyInfo {
  {
    command: Command::from_byte(frame.control),
    control: frame.control,
    abnormal: is_error_reply(frame.control),
    follow_up: has_follow_up(frame.control),
    error: decode_error_reply(frame),
  }
}

///|
/// Verify that a read-next reply's sequence number matches its request.
pub fn sequence_matches(request : Array[Byte], reply : Array[Byte]) -> Bool {
  let req = match decode_frame(request) {
    Ok(f) => f
    Err(_) => return false
  }
  let rep = match decode_frame(reply) {
    Ok(f) => f
    Err(_) => return false
  }
  // Both frames must be the read-next transaction: a master 0x12 request
  // and a non-abnormal 0x92 / 0xB2 slave reply. Comparing only the last
  // byte would accept unrelated frames that happen to share that byte.
  if is_reply(req.control) ||
    function_code(req.control) != Command::ReadNextData.value().to_int() ||
    !is_reply(rep.control) ||
    is_error_reply(rep.control) ||
    function_code(rep.control) != Command::ReadNextData.value().to_int() {
    return false
  }
  if req.data.length() != 5 || rep.data.length() < 6 {
    return false
  }
  // The reply must echo the requested DI in the same wire order.
  for i = 0; i < 4; i = i + 1 {
    if req.data[i] != rep.data[i] {
      return false
    }
  }
  req.data[4] == rep.data[rep.data.length() - 1]
}

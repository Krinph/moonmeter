///|
/// DL/T 645-2007 protocol constants (conformant definitions).
///
/// Frame layout, exactly as defined by the standard:
///   START(68H) | ADDR(6x BCD, low byte first) | START(68H) | C(1) | L(1)
///   | DATA(L) | CS(1) | END(16H)
///
///   L is a SINGLE byte counting the DATA bytes (the +0x33 offset is already
///   part of those bytes). A frame without preamble is 12 + L bytes long.
///   The DATA field is transmitted with every byte offset by +0x33; the
///   receiver subtracts 0x33. CS is the modulo-256 sum from the first 68H
///   through the last DATA byte, i.e. over the transmitted (offset) bytes.
///
/// Control code C bit layout:
///   D7 = direction      0 = master command, 1 = slave reply
///   D6 = reply flag     0 = normal reply,   1 = abnormal (error) reply
///   D5 = follow-up      0 = no more frames, 1 = more frames follow
///   D4..D0 = function code (see `Command`)
///
/// Consequently a master read-data command is 0x11 (0001_0001), a normal
/// read-data reply is 0x91 (1001_0001), and an abnormal read-data reply is
/// 0xD1 (1101_0001). The value 0x01 alone is NOT a DL/T 645-2007 command,
/// and 0xC1 is NOT the standard abnormal-reply control code.

///|
pub const FrameStart : Byte = 0x68

///|
pub const FrameEnd : Byte = 0x16

///|
/// Offset added to every DATA byte on the wire (subtracted on receive).
pub const DataOffset : Byte = 0x33

///|
/// Direction bit in the control code: set on slave replies.
pub const ControlDirection : Int32 = 0x80

///|
/// Abnormal-reply bit in the control code (meaningful on slave replies).
pub const ControlAbnormal : Int32 = 0x40

///|
/// Follow-up-frame bit in the control code.
pub const ControlFollowUp : Int32 = 0x20

///|
/// Mask for the function code (D4..D0) of a control byte.
pub const ControlFunctionMask : Int32 = 0x1F

///|
/// DL/T 645-2007 master function codes, as defined in the standard's
/// control-code table. They are intentionally non-contiguous: this is a
/// frequent source of interoperability bugs.
pub enum Command {
  BroadcastTimeSync = 0x08
  ReadData = 0x11
  ReadNextData = 0x12
  ReadAddress = 0x13
  WriteData = 0x14
  WriteAddress = 0x15
  Freeze = 0x16
  ChangeBaudRate = 0x17
  ChangePassword = 0x18
  ClearMaxDemand = 0x19
  ClearMeter = 0x1A
  ClearEvents = 0x1B
}

///|
/// The wire value of a master function code.
pub fn Command::value(self : Command) -> Byte {
  match self {
    BroadcastTimeSync => 0x08
    ReadData => 0x11
    ReadNextData => 0x12
    ReadAddress => 0x13
    WriteData => 0x14
    WriteAddress => 0x15
    Freeze => 0x16
    ChangeBaudRate => 0x17
    ChangePassword => 0x18
    ClearMaxDemand => 0x19
    ClearMeter => 0x1A
    ClearEvents => 0x1B
  }
}

///|
/// Decode a control byte's function part (D4..D0) back to a `Command`.
/// Works for both master commands (0x11) and slave replies (0x91 / 0xD1),
/// because only the low five bits carry the function code.
pub fn Command::from_byte(b : Byte) -> Command? {
  match b.to_int() & ControlFunctionMask {
    0x08 => Some(BroadcastTimeSync)
    0x11 => Some(ReadData)
    0x12 => Some(ReadNextData)
    0x13 => Some(ReadAddress)
    0x14 => Some(WriteData)
    0x15 => Some(WriteAddress)
    0x16 => Some(Freeze)
    0x17 => Some(ChangeBaudRate)
    0x18 => Some(ChangePassword)
    0x19 => Some(ClearMaxDemand)
    0x1A => Some(ClearMeter)
    0x1B => Some(ClearEvents)
    _ => None
  }
}

///|
/// Build a normal (non-abnormal) slave reply control byte for a function.
/// For read data: 0x11 -> 0x91.
pub fn normal_reply_control(function : Byte) -> Byte {
  (ControlDirection | function.to_int()).to_byte()
}

///|
/// Build an abnormal slave reply control byte for a function.
/// For read data: 0x11 -> 0xD1 (D7 + D6 set).
pub fn abnormal_reply_control(function : Byte) -> Byte {
  (ControlDirection | ControlAbnormal | function.to_int()).to_byte()
}

///|
/// Data identifier (DI3 DI2 DI1 DI0) for a reading.
///
/// The struct stores the four bytes in their STANDARD NOTATION order:
/// `di3` is the most-significant identifier byte, `di0` the least. On the
/// wire a DI is transmitted low byte first (DI0, DI1, DI2, DI3) and then
/// offset by +0x33, exactly like every other DATA byte.
pub struct DataId {
  di3 : Int32
  di2 : Int32
  di1 : Int32
  di0 : Int32
}

///|
/// Construct a data identifier from its standard DI3..DI0 notation.
pub fn DataId::new(
  di3 : Int32,
  di2 : Int32,
  di1 : Int32,
  di0 : Int32,
) -> DataId {
  { di3, di2, di1, di0, }
}

///|
/// Current forward active total energy, DI3DI2DI1DI0 = 00010000.
/// On the wire this is transmitted as 00 00 01 00, then +0x33.
pub fn di_active_total() -> DataId {
  DataId::new(0, 1, 0, 0)
}

///|
/// Current forward active peak energy, 00010100.
pub fn di_active_peak() -> DataId {
  DataId::new(0, 1, 1, 0)
}

///|
/// Current forward active flat energy, 00010200.
pub fn di_active_flat() -> DataId {
  DataId::new(0, 1, 2, 0)
}

///|
/// Current forward active shoulder energy, 00010300.
pub fn di_active_peak2() -> DataId {
  DataId::new(0, 1, 3, 0)
}

///|
/// Current forward active valley energy, 00010400.
pub fn di_active_valley() -> DataId {
  DataId::new(0, 1, 4, 0)
}

///|
/// Phase A voltage, DI3DI2DI1DI0 = 02010100.
pub fn di_voltage() -> DataId {
  DataId::new(2, 1, 1, 0)
}

///|
/// Phase A current, DI3DI2DI1DI0 = 02020100.
pub fn di_current() -> DataId {
  DataId::new(2, 2, 1, 0)
}

///|
/// Total instantaneous active power, DI3DI2DI1DI0 = 02030000.
pub fn di_power() -> DataId {
  DataId::new(2, 3, 0, 0)
}

///|
/// The four DI bytes in WIRE order: DI0, DI1, DI2, DI3 (before +0x33).
pub fn DataId::wire_bytes(self : DataId) -> Array[Byte] {
  [
    self.di0.to_byte(),
    self.di1.to_byte(),
    self.di2.to_byte(),
    self.di3.to_byte(),
  ]
}

///|
/// Standard notation of a data identifier, DI3 DI2 DI1 DI0 as hex text.
pub fn DataId::to_string(self : DataId) -> String {
  di_byte_hex(self.di3) +
  di_byte_hex(self.di2) +
  di_byte_hex(self.di1) +
  di_byte_hex(self.di0)
}

///|
/// Format a byte value as exactly two uppercase hex digits.
fn di_byte_hex(value : Int32) -> String {
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let hi = (value >> 4) & 0x0F
  let lo = value & 0x0F
  digits[hi].to_string() + digits[lo].to_string()
}

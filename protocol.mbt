///|
/// DL/T 645-2007 protocol constants.
///
/// Frame layout (all multi-byte fields are little-endian):
///   START(68H) | ADDR(6x BCD) | START(68H) | C(1) | L(2) | DATA(L) | CS(1) | END(16H)
///
/// CS is the sum (mod 256) of every byte from the first 68H through the last
/// DATA byte.

///|
pub const FrameStart : Byte = 0x68

///|
pub const FrameEnd : Byte = 0x16

///|
/// DL/T 645 control codes (master -> slave).
pub enum Command {
  ReadData = 0x01
  ReadNextData = 0x02
  WriteDataMulti = 0x03
  WriteAddress = 0x04
  BroadcastTimeSync = 0x05
  WriteDataSingle = 0x06
  ReadAddress = 0x07
  ChangePassword = 0x08
  ClearMaxDemand = 0x09
  ClearMeter = 0x0A
  ClearEvents = 0x0B
  ReadBlocks = 0x0C
  ReadEvents = 0x0D
  Freeze = 0x0E
  ReadVersion = 0x0F
}

///|
/// The byte value of a command.
pub fn Command::value(self : Command) -> Byte {
  match self {
    ReadData => 0x01
    ReadNextData => 0x02
    WriteDataMulti => 0x03
    WriteAddress => 0x04
    BroadcastTimeSync => 0x05
    WriteDataSingle => 0x06
    ReadAddress => 0x07
    ChangePassword => 0x08
    ClearMaxDemand => 0x09
    ClearMeter => 0x0A
    ClearEvents => 0x0B
    ReadBlocks => 0x0C
    ReadEvents => 0x0D
    Freeze => 0x0E
    ReadVersion => 0x0F
  }
}

///|
/// Decode a control byte's function part back to a `Command`, if known.
/// Handles both request bytes (0x01..0x0F) and reply bytes (0x81..0x8F).
pub fn Command::from_byte(b : Byte) -> Command? {
  match b.to_int() & 0x1F {
    0x01 => Some(ReadData)
    0x02 => Some(ReadNextData)
    0x03 => Some(WriteDataMulti)
    0x04 => Some(WriteAddress)
    0x05 => Some(BroadcastTimeSync)
    0x06 => Some(WriteDataSingle)
    0x07 => Some(ReadAddress)
    0x08 => Some(ChangePassword)
    0x09 => Some(ClearMaxDemand)
    0x0A => Some(ClearMeter)
    0x0B => Some(ClearEvents)
    0x0C => Some(ReadBlocks)
    0x0D => Some(ReadEvents)
    0x0E => Some(Freeze)
    0x0F => Some(ReadVersion)
    _ => None
  }
}

///|
/// Data identifier (DI0..DI3) for the most common readings.
/// In the DATA field the identifiers are sent in order DI0, DI1, DI2, DI3
/// (each one byte); the last byte carries the value length in the upper
/// nibble and the decimal places in the lower nibble for the request.
pub struct DataId {
  di0 : Int32
  di1 : Int32
  di2 : Int32
  di3 : Int32
}

///|
/// Convenience constructor.
pub fn DataId::new(
  di0 : Int32,
  di1 : Int32,
  di2 : Int32,
  di3 : Int32,
) -> DataId {
  { di0, di1, di2, di3, }
}

///|
/// Common DI sets for active energy readings (kWh).
pub fn di_active_total() -> DataId {
  DataId::new(0, 0, 0, 0)
}

///|
pub fn di_active_peak() -> DataId {
  DataId::new(0, 0, 0, 1)
}

///|
pub fn di_active_flat() -> DataId {
  DataId::new(0, 0, 0, 2)
}

///|
pub fn di_active_peak2() -> DataId {
  DataId::new(0, 0, 0, 3)
}

///|
pub fn di_active_valley() -> DataId {
  DataId::new(0, 0, 0, 4)
}

///|
pub fn di_voltage() -> DataId {
  DataId::new(0, 1, 0, 1)
}

///|
pub fn di_current() -> DataId {
  DataId::new(0, 2, 0, 1)
}

///|
pub fn di_power() -> DataId {
  DataId::new(0, 3, 0, 1)
}

///|
/// Decode the value length (upper nibble) of the DI3 request byte.
/// A byte value like 0x41 means 4 digits and 1 decimal place (XXX.X).
pub fn di3_len(di3 : Int32) -> Int32 {
  (di3 >> 4) & 0xF
}

///|
pub fn di3_decimals(di3 : Int32) -> Int32 {
  di3 & 0xF
}

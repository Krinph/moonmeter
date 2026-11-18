///|
/// DL/T 645-2007 frame encode/decode.
///
/// A frame is:
///   START(68H) ADDR[6] START(68H) C L(2) DATA[L] CS END(16H)
/// where ADDR is 6 BCD bytes (low byte first), L is little-endian, and CS is
/// the modulo-256 sum of all bytes before it.

///|
/// A parsed DL/T 645 frame.
pub struct Frame {
  /// 6-byte BCD address (bytes as received, low byte first).
  address : Array[Byte]
  /// Control code (see `Command`; bit 7 set = slave reply).
  control : Byte
  /// Raw data field bytes.
  data : Array[Byte]
}

///|
/// Errors produced by the frame decoder.
pub enum FrameError {
  TooShort
  BadStart
  BadEnd
  BadChecksum
  LengthMismatch
}

///|
/// Encode a full frame from its parts.
pub fn encode_frame(
  address : Array[Byte],
  control : Byte,
  data : Array[Byte],
) -> Array[Byte] {
  let out : Array[Byte] = []
  out.push(FrameStart)
  for b in address {
    out.push(b)
  }
  out.push(FrameStart)
  out.push(control)
  let len = data.length()
  out.push((len & 0xFF).to_byte())
  out.push(((len >> 8) & 0xFF).to_byte())
  for b in data {
    out.push(b)
  }
  let cs = checksum(out)
  out.push(cs)
  out.push(FrameEnd)
  out
}

///|
/// Decode a frame. Returns the decoded frame, or a `FrameError` if the input
/// is not a valid DL/T 645 frame.
pub fn decode_frame(bytes : Array[Byte]) -> Result[Frame, FrameError] {
  if bytes.length() < 13 {
    return Err(FrameError::TooShort)
  }
  if bytes[0] != FrameStart {
    return Err(FrameError::BadStart)
  }
  if bytes[7] != FrameStart {
    return Err(FrameError::BadStart)
  }
  // Control is byte 8; length is bytes 9..10 (little-endian).
  let len = bytes[9].to_int() | (bytes[10].to_int() << 8)
  // Frame is 11 header bytes + len data + CS + END.
  if 11 + len + 2 > bytes.length() {
    return Err(FrameError::LengthMismatch)
  }
  // CS covers bytes [0 .. 10+len] inclusive (11+len bytes).
  let cs = checksum(bytes[0:11 + len])
  if cs != bytes[11 + len] {
    return Err(FrameError::BadChecksum)
  }
  if bytes[11 + len + 1] != FrameEnd {
    return Err(FrameError::BadEnd)
  }
  let address : Array[Byte] = []
  for i = 1; i <= 6; i = i + 1 {
    address.push(bytes[i])
  }
  let data : Array[Byte] = []
  for i = 11; i < 11 + len; i = i + 1 {
    data.push(bytes[i])
  }
  Ok({ address, control: bytes[8], data, })
}

///|
/// Compute the DL/T 645 checksum: the sum of all bytes modulo 256.
fn checksum(bytes : ArrayView[Byte]) -> Byte {
  let mut sum = 0
  for b in bytes {
    sum = sum + b.to_int()
  }
  (sum & 0xFF).to_byte()
}

///|
/// A single BCD byte from a two-digit decimal value.
pub fn bcd_from(value : Int32) -> Byte {
  let tens = value / 10 % 10
  let ones = value % 10
  ((tens << 4) | ones).to_byte()
}

///|
/// Decode a BCD byte into its integer value (0..99).
pub fn bcd_to(b : Byte) -> Int32 {
  (b >> 4).to_int() * 10 + (b & 0x0F).to_int()
}

///|
/// Encode a multi-digit decimal value as BCD bytes (least significant
/// first), using exactly `digits` / 2 bytes (digits must be even).
pub fn bcd_encode(value : Int32, digits : Int32) -> Array[Byte] {
  let out : Array[Byte] = []
  let mut v = value
  for _i = 0; _i < digits / 2; _i = _i + 1 {
    out.push(bcd_from(v % 100))
    v = v / 100
  }
  out
}

///|
/// Decode BCD bytes (least significant first) into an integer.
pub fn bcd_decode(bytes : ArrayView[Byte]) -> Int32 {
  let mut result = 0
  let mut factor = 1
  for i = 0; i < bytes.length(); i = i + 1 {
    result = result + bcd_to(bytes[i]) * factor
    factor = factor * 100
  }
  result
}

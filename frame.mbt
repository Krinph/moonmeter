///|
/// DL/T 645-2007 frame encode/decode, conformant to the standard.
///
/// Wire layout (preamble FE bytes are optional and stripped by callers):
///   68 ADDR[6] 68 C L DATA[L] CS 16
///   - ADDR: 6 BCD bytes, low byte first; NOT offset by 0x33.
///   - C: control code; NOT offset.
///   - L: ONE byte, number of DATA bytes on the wire.
///   - DATA: every byte is (logical + 0x33) & 0xFF on the wire.
///   - CS: modulo-256 sum from the first 68H through the last DATA byte,
///         computed on the transmitted (offset) bytes.
///   - Ends with 16H. Total length without preamble = 12 + L.
///
/// Public `encode_frame` / `decode_frame` work with LOGICAL data bytes:
/// encoding applies +0x33 internally, decoding removes it internally.
/// Use `offset_data` / `unoffset_data` for raw wire manipulation.

///|
/// A parsed DL/T 645 frame with its DATA field restored to logical bytes.
pub struct Frame {
  /// 6-byte BCD address (as received, low byte first).
  address : Array[Byte]
  /// Control code; bit 7 set = slave reply, bit 6 set = abnormal reply.
  control : Byte
  /// Logical DATA bytes (already de-offset by -0x33).
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
/// Apply the DL/T 645 +0x33 offset to each DATA byte (transmit side).
pub fn offset_data(data : ArrayView[Byte]) -> Array[Byte] {
  let out : Array[Byte] = []
  for b in data {
    out.push(((b.to_int() + DataOffset.to_int()) & 0xFF).to_byte())
  }
  out
}

///|
/// Remove the DL/T 645 +0x33 offset from each DATA byte (receive side).
pub fn unoffset_data(data : ArrayView[Byte]) -> Array[Byte] {
  let out : Array[Byte] = []
  for b in data {
    out.push(((b.to_int() - DataOffset.to_int() + 0x100) & 0xFF).to_byte())
  }
  out
}

///|
/// Encode a full frame from logical parts. The DATA field is offset by
/// +0x33 and the checksum is computed over the transmitted bytes.
pub fn encode_frame(
  address : Array[Byte],
  control : Byte,
  logical_data : Array[Byte],
) -> Array[Byte] {
  let wire_data = offset_data(logical_data)
  let out : Array[Byte] = []
  out.push(FrameStart)
  for b in address {
    out.push(b)
  }
  out.push(FrameStart)
  out.push(control)
  out.push(wire_data.length().to_byte())
  for b in wire_data {
    out.push(b)
  }
  out.push(checksum(out))
  out.push(FrameEnd)
  out
}

///|
/// Decode a frame. The DATA field is returned with the +0x33 offset removed.
pub fn decode_frame(bytes : Array[Byte]) -> Result[Frame, FrameError] {
  // Minimum frame: 68 ADDR[6] 68 C L CS 16 = 12 bytes (L = 0).
  if bytes.length() < 12 {
    return Err(FrameError::TooShort)
  }
  if bytes[0] != FrameStart {
    return Err(FrameError::BadStart)
  }
  if bytes[7] != FrameStart {
    return Err(FrameError::BadStart)
  }
  // Single-byte length at index 9; DATA occupies 10 .. 10+L.
  let len = bytes[9].to_int()
  let frame_len = 12 + len
  if frame_len > bytes.length() {
    return Err(FrameError::LengthMismatch)
  }
  // CS covers bytes [0 .. 9+L] inclusive, i.e. first 68H through last DATA.
  if checksum(bytes[0:10 + len]) != bytes[10 + len] {
    return Err(FrameError::BadChecksum)
  }
  if bytes[10 + len + 1] != FrameEnd {
    return Err(FrameError::BadEnd)
  }
  let address : Array[Byte] = []
  for i = 1; i <= 6; i = i + 1 {
    address.push(bytes[i])
  }
  let data = unoffset_data(bytes[10:10 + len])
  Ok({ address, control: bytes[8], data, })
}

///|
/// Compute the DL/T 645 checksum: modulo-256 sum of the given bytes.
pub fn checksum(bytes : ArrayView[Byte]) -> Byte {
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

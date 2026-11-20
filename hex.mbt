///|
/// Hex helpers for CLI and testing.

///|
/// Parse a hex string (space or comma separated, or contiguous) into bytes.
/// Returns `None` on malformed input.
pub fn hex_decode(text : String) -> Array[Byte]? {
  let cleaned = text.replace_all(old=" ", new="").replace_all(old=",", new="")
  if cleaned.length() % 2 != 0 {
    return None
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < cleaned.length() {
    let hi = hex_digit(cleaned[i])
    let lo = hex_digit(cleaned[i + 1])
    match (hi, lo) {
      (Some(h), Some(l)) => out.push(((h << 4) | l).to_byte())
      _ => return None
    }
    i = i + 2
  }
  Some(out)
}

///|
/// Format a single byte as exactly two uppercase hex digits.
pub fn hex_byte(b : Byte) -> String {
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let hi = ((b >> 4) & 0x0F).to_int()
  let lo = (b & 0x0F).to_int()
  digits[hi].to_string() + digits[lo].to_string()
}

///|
/// Format bytes as uppercase hex, space separated.
pub fn hex_encode(bytes : ArrayView[Byte]) -> String {
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let parts : Array[String] = []
  for b in bytes {
    let hi = ((b >> 4) & 0x0F).to_int()
    let lo = (b & 0x0F).to_int()
    parts.push(digits[hi].to_string() + digits[lo].to_string())
  }
  parts.join(" ")
}

///|
fn hex_digit(c : UInt16) -> Int32? {
  let v = c.to_int()
  if v >= 48 && v <= 57 {
    return Some(v - 48)
  }
  if v >= 97 && v <= 102 {
    return Some(v - 97 + 10)
  }
  if v >= 65 && v <= 70 {
    return Some(v - 65 + 10)
  }
  None
}

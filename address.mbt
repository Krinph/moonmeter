///|
/// DL/T 645 meter address helpers.
///
/// A DL/T 645 address is 6 BCD bytes (12 decimal digits), transmitted low
/// byte first. These helpers validate such addresses and convert between the
/// human-facing 12-digit form and the on-wire byte form, so callers cannot
/// accidentally build frames with an invalid address.

///|
/// Validate a 6-byte address: it must have exactly 6 bytes and every nibble
/// must be a valid BCD digit (0..9).
pub fn valid_address(addr : ArrayView[Byte]) -> Bool {
  if addr.length() != 6 {
    return false
  }
  for b in addr {
    if (b & 0x0F).to_int() > 9 || ((b >> 4) & 0x0F).to_int() > 9 {
      return false
    }
  }
  true
}

///|
/// Convert a 12-digit decimal address string into 6 BCD bytes (low byte
/// first). Returns `None` if the string is not exactly 12 decimal digits.
pub fn address_from_digits(digits : String) -> Array[Byte]? {
  if digits.length() != 12 {
    return None
  }
  let out : Array[Byte] = []
  // Walk from the least significant pair of digits (rightmost) to the left.
  let mut end = 12
  while end >= 2 {
    let hi = decimal_digit(digits[end - 2])
    let lo = decimal_digit(digits[end - 1])
    match (hi, lo) {
      (Some(h), Some(l)) => out.push(((h << 4) | l).to_byte())
      _ => return None
    }
    end = end - 2
  }
  Some(out)
}

///|
/// Format a 6-byte address as its 12-digit decimal string (high byte first).
/// Returns `None` if the address is not a valid BCD address.
pub fn address_to_digits(addr : ArrayView[Byte]) -> String? {
  if !valid_address(addr) {
    return None
  }
  let sb = StringBuilder()
  let mut i = 5
  while i >= 0 {
    let b = addr[i]
    sb.write_char(digit_char(((b >> 4) & 0x0F).to_int()))
    sb.write_char(digit_char((b & 0x0F).to_int()))
    i = i - 1
  }
  Some(sb.to_string())
}

///|
fn decimal_digit(c : UInt16) -> Int32? {
  let v = c.to_int()
  if v >= 48 && v <= 57 {
    return Some(v - 48)
  }
  None
}

///|
fn digit_char(value : Int32) -> Char {
  let digits : Array[Char] = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
  digits[value]
}

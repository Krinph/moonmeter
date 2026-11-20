///|
/// Human-readable metadata for the common DL/T 645 data identifiers.
///
/// A raw `DataId` (DI0..DI3) tells a master *which* register to read, but not
/// what the value means or how to display it. This module supplies that layer:
/// a name, a unit and the number of decimal places, so callers can turn a
/// decoded reading into a labelled value without maintaining their own table.

///|
/// Display metadata for one data identifier.
pub struct DiInfo {
  /// Short human-readable name, e.g. "Total active energy".
  name : String
  /// Physical unit, e.g. "kWh".
  unit : String
  /// Number of decimal places carried by the raw BCD value.
  decimals : Int32
}

///|
/// Look up metadata for a known data identifier.
/// Returns `None` for identifiers outside the built-in catalog.
pub fn di_info(di : DataId) -> DiInfo? {
  if di.di0 == 0 && di.di1 == 0 && di.di2 == 0 {
    match di.di3 {
      0 => Some({ name: "Total active energy", unit: "kWh", decimals: 2, })
      1 => Some({ name: "Peak active energy", unit: "kWh", decimals: 2, })
      2 => Some({ name: "Flat active energy", unit: "kWh", decimals: 2, })
      3 => Some({ name: "Peak-2 active energy", unit: "kWh", decimals: 2, })
      4 => Some({ name: "Valley active energy", unit: "kWh", decimals: 2, })
      _ => None
    }
  } else if di.di0 == 0 && di.di2 == 0 && di.di3 == 1 {
    match di.di1 {
      1 => Some({ name: "Voltage", unit: "V", decimals: 1, })
      2 => Some({ name: "Current", unit: "A", decimals: 2, })
      3 => Some({ name: "Power", unit: "kW", decimals: 3, })
      _ => None
    }
  } else {
    None
  }
}

///|
/// A display label for a data identifier. Known identifiers get their name;
/// unknown ones fall back to the four DI bytes in hex so nothing is hidden.
pub fn di_label(di : DataId) -> String {
  match di_info(di) {
    Some(info) => info.name
    None => {
      let label =
        "DI " +
        byte_hex(di.di0) +
        byte_hex(di.di1) +
        byte_hex(di.di2) +
        byte_hex(di.di3)
      label
    }
  }
}

///|
/// Format a byte as exactly two uppercase hex digits.
fn byte_hex(value : Int32) -> String {
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E',
    'F',
  ]
  let hi = ((value >> 4) & 0x0F)
  let lo = (value & 0x0F)
  digits[hi].to_string() + digits[lo].to_string()
}


///|
/// Human-readable metadata for common DL/T 645-2007 data identifiers.
///
/// A raw `DataId` tells a master *which* register to read, but not what the
/// value means or how to display it. This module supplies the name, unit
/// and decimal places, following the DI definitions in the standard's
/// Appendix A (data-identifier coding table).

///|
/// Display metadata for one data identifier.
pub struct DiInfo {
  /// Short human-readable name, e.g. "Forward active total energy".
  name : String
  /// Physical unit, e.g. "kWh".
  unit : String
  /// Number of decimal places carried by the raw BCD value.
  decimals : Int32
}

///|
/// Look up metadata for a known data identifier (DI3 DI2 DI1 DI0).
/// Returns `None` for identifiers outside the built-in catalog.
pub fn di_info(di : DataId) -> DiInfo? {
  if di.di3 == 0 && di.di2 == 1 {
    if di.di0 == 0 && di.di1 >= 0 && di.di1 <= 4 {
      // 0001x000 (x = 0..4): forward active energy, total / peak / flat /
      // shoulder / valley, 2 decimals, kWh.
      let names : Array[String] = [
        "Forward active total energy", "Forward active peak energy", "Forward active flat energy",
        "Forward active shoulder energy", "Forward active valley energy",
      ]
      Some({ name: names[di.di1], unit: "kWh", decimals: 2, })
    } else {
      None
    }
  } else if di.di3 == 2 && di.di2 == 1 && di.di1 == 1 && di.di0 == 0 {
    // 02010100: phase A voltage, 1 decimal, V.
    Some({ name: "Phase A voltage", unit: "V", decimals: 1, })
  } else if di.di3 == 2 && di.di2 == 2 && di.di1 == 1 && di.di0 == 0 {
    // 02020100: phase A current, 3 decimals, A.
    Some({ name: "Phase A current", unit: "A", decimals: 3, })
  } else if di.di3 == 2 && di.di2 == 3 && di.di1 == 0 && di.di0 == 0 {
    // 02030000: total instantaneous active power, 2 decimals, kW.
    Some({ name: "Total active power", unit: "kW", decimals: 2, })
  } else {
    None
  }
}

///|
/// A display label for a data identifier. Known identifiers get their name;
/// unknown ones fall back to the four DI bytes in standard hex notation.
pub fn di_label(di : DataId) -> String {
  match di_info(di) {
    Some(info) => info.name
    None => {
      let label = "DI " + di.to_string()
      label
    }
  }
}

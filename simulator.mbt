///|
/// A virtual DL/T 645-2007 meter used for simulation and testing.
///
/// The simulator owns a set of readings (DI -> value bytes) and can:
///   - answer a read-data request with a valid 0x91 reply frame;
///   - generate a live data stream (frames with configurable errors) so that
///     master implementations and protocol testers can be exercised offline.
///
/// This makes moonmeter a complete round-trip toolkit: encode -> transmit ->
/// decode -> validate, all without real hardware.

///|
pub struct MeterSim {
  address : Array[Byte]
  /// readings: DI key (a 4-byte packed value) -> value bytes.
  readings : Map[Int32, Array[Byte]]
}

///|
pub fn MeterSim::new(address : Array[Byte]) -> MeterSim {
  { address, readings: Map([]), }
}

///|
fn di_key(di : DataId) -> Int32 {
  (di.di0 << 24) | (di.di1 << 16) | (di.di2 << 8) | di.di3
}

///|
/// Register a reading (DI -> value bytes).
pub fn MeterSim::set_reading(
  self : MeterSim,
  di : DataId,
  value : Array[Byte],
) -> Unit {
  self.readings[di_key(di)] = value
}

///|
/// Reply to a read-data request frame. Returns the reply frame bytes, or
/// `None` if the request is malformed.
pub fn MeterSim::answer_read(
  self : MeterSim,
  request : Array[Byte],
) -> Array[Byte]? {
  let frame = match decode_frame(request) {
    Ok(f) => f
    Err(_) => return None
  }
  if function_code(frame.control) != Command::ReadData.value().to_int() {
    return None
  }
  if frame.data.length() < 4 {
    return None
  }
  // Request DATA holds DI0..DI3 in wire order; rebuild the DI structure.
  let di = DataId::new(
    frame.data[3].to_int(),
    frame.data[2].to_int(),
    frame.data[1].to_int(),
    frame.data[0].to_int(),
  )
  let value = self.readings.get(di_key(di))
  let value_bytes = match value {
    Some(v) => v
    None => return None
  }
  let reply_data : Array[Byte] = []
  for b in di.wire_bytes() {
    reply_data.push(b)
  }
  for b in value_bytes {
    reply_data.push(b)
  }
  // Normal read-data reply control = 0x91 (D7 reply + function 0x11).
  let reply_control = normal_reply_control(Command::ReadData.value())
  Some(encode_frame(self.address, reply_control, reply_data))
}

///|
/// Generate a synthetic frame stream exercising the given readings, with an
/// optional corruption of the checksum to test a validator.
pub fn MeterSim::generate_stream(
  self : MeterSim,
  corrupt_last : Bool,
) -> Array[Byte] {
  let out : Array[Byte] = []
  for kv in self.readings {
    // di_key packs di0 in the highest byte; reverse it to rebuild the DI.
    let di = DataId::new(
      kv.0 & 0xFF,
      (kv.0 >> 8) & 0xFF,
      (kv.0 >> 16) & 0xFF,
      (kv.0 >> 24) & 0xFF,
    )
    let reply_data : Array[Byte] = []
    for b in di.wire_bytes() {
      reply_data.push(b)
    }
    for b in kv.1 {
      reply_data.push(b)
    }
    let frame = encode_frame(
      self.address,
      normal_reply_control(Command::ReadData.value()),
      reply_data,
    )
    for b in frame {
      out.push(b)
    }
  }
  if corrupt_last && out.length() > 2 {
    let last = out.length() - 1
    let fix : Byte = if out[last] == 0x16 { 0x15 } else { 0x16 }
    out[last] = fix
  }
  out
}

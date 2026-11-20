///|
/// moonmeter round-trip example.
///
/// Demonstrates the complete hardware-free reading loop:
///   build request -> simulate meter reply -> decode reading -> format value
///   -> validate the wire stream for protocol conformance.
///
/// Run with: moon run cmd/roundtrip

///|
fn main {
  let address : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
  let di = @moonmeter.di_active_total()

  println("1. build read request")
  let request = @moonmeter.build_read_request(address, di)
  println("   " + @moonmeter.hex_encode(request))

  println("2. simulate an electricity meter")
  let meter = @moonmeter.MeterSim::new(address)
  meter.set_reading(di, [0x56, 0x34, 0x12, 0x00])
  let reply = meter.answer_read(request).unwrap()
  println("   " + @moonmeter.hex_encode(reply))

  println("3. decode and label the reading")
  let frame = @moonmeter.decode_frame(reply).unwrap()
  let reading = @moonmeter.parse_reading(frame.data).unwrap()
  println("   " + @moonmeter.di_label(reading.di))

  println("4. format the value")
  let (raw, decimals) = @moonmeter.decode_energy(reading.value, 2)
  println("   " + @moonmeter.format_energy(raw, decimals) + " kWh")

  println("5. validate the wire stream")
  let stream = meter.generate_stream(false)
  let (frames, findings) = @moonmeter.validate_stream(stream)
  let (errors, warnings) = @moonmeter.count_findings(findings)
  println(
    "   " +
    frames.length().to_string() +
    " frame(s), " +
    errors.to_string() +
    " error(s), " +
    warnings.to_string() +
    " warning(s)",
  )
}

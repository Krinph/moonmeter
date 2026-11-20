///|
/// moonmeter CLI: parse, validate and simulate DL/T 645 frames.
///
/// Subcommands:
///   parse <hex>       decode one frame and print its structure
///   validate <hex>    split a stream and report conformance findings
///   read <hex-addr>   build a read-data request frame (DI=00000000)
///   simulate          print a synthetic meter stream (two readings)
///   simulate --bad    print a stream with a corrupted ending byte

///|
fn main {
  let cmd = @argparse.Command::Command(
    "moonmeter",
    about="DL/T 645-2007 electricity meter protocol toolkit",
    version="0.2.0",
    arg_required_else_help=true,
    options=[
      @argparse.OptionArg::OptionArg(
        "address",
        short='a',
        long="address",
        about="meter address as 6 hex bytes (e.g. 000102030405)",
        default_values=["000102030405"],
      ),
    ],
    flags=[
      @argparse.FlagArg::FlagArg(
        "bad",
        long="bad",
        about="simulate: corrupt the final byte",
      ),
    ],
    subcommands=[
      @argparse.Command::Command(
        "parse",
        about="decode a hex frame and print its structure",
        arg_required_else_help=true,
        positionals=[
          @argparse.PositionArg::PositionArg(
            "hex",
            about="hex bytes of the frame",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
      @argparse.Command::Command(
        "validate",
        about="split a hex stream and report conformance findings",
        arg_required_else_help=true,
        positionals=[
          @argparse.PositionArg::PositionArg(
            "hex",
            about="hex bytes of the stream",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
      @argparse.Command::Command(
        "read",
        about="build a read-data request frame (DI 00000000)",
      ),
      @argparse.Command::Command(
        "simulate",
        about="print a synthetic meter stream",
        flags=[
          @argparse.FlagArg::FlagArg(
            "bad",
            long="bad",
            about="corrupt the final byte",
          ),
        ],
      ),
    ],
  )
  let outcome = cmd.parse_outcome(argv=@env.args()[1:])
  match outcome {
    @argparse.ParseOutcome::Parsed(matches) => run(matches)
    @argparse.ParseOutcome::Help(text) => println(text)
    @argparse.ParseOutcome::Version(text) => println(text)
    @argparse.ParseOutcome::Failed(err) => println("error: " + err.to_string())
  }
}

///|
fn run(matches : @argparse.Matches) -> Unit {
  match matches.subcommand {
    Some(("parse", sub)) => {
      let hex = sub.values.get("hex").unwrap_or([])[0]
      cmd_parse(hex)
    }
    Some(("validate", sub)) => {
      let hex = sub.values.get("hex").unwrap_or([])[0]
      cmd_validate(hex)
    }
    Some(("read", _)) => {
      let addr_hex = matches.values.get("address").unwrap_or(["000102030405"])[0]
      cmd_read(addr_hex)
    }
    Some(("simulate", sub)) => {
      let addr_hex = matches.values.get("address").unwrap_or(["000102030405"])[0]
      let bad = sub.flags.get("bad").unwrap_or(false)
      cmd_simulate(addr_hex, bad)
    }
    _ => println("error: unknown command")
  }
}

///|
fn cmd_parse(hex : String) -> Unit {
  let bytes = @moonmeter.hex_decode(hex)
  let bytes = match bytes {
    Some(b) => b
    None => {
      println("error: invalid hex")
      return
    }
  }
  let frame = @moonmeter.decode_frame(bytes)
  match frame {
    Ok(f) => {
      let digits : Array[Char] = [
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E',
        'F',
      ]
      println("frame: OK")
      println("  address : " + @moonmeter.hex_encode(f.address))
      println(
        "  control : 0x" +
        digits[((f.control >> 4) & 0x0F).to_int()].to_string() +
        digits[(f.control & 0x0F).to_int()].to_string(),
      )
      println(
        "  function: " +
        @moonmeter.function_code(f.control).to_string() +
        (if @moonmeter.is_reply(f.control) { " (reply)" } else { "" }),
      )
      println("  data    : " + @moonmeter.hex_encode(f.data))
      match @moonmeter.parse_reading(f.data) {
        Some(reading) =>
          println("  di      : " + @moonmeter.di_label(reading.di))
        None => ()
      }
      match @moonmeter.decode_error_reply(f) {
        Some(code) => println("  error   : " + code.label())
        None => ()
      }
    }
    Err(e) => println("frame: ERROR (" + frame_error_label(e) + ")")
  }
}

///|
fn cmd_validate(hex : String) -> Unit {
  let bytes = match @moonmeter.hex_decode(hex) {
    Some(b) => b
    None => {
      println("error: invalid hex")
      return
    }
  }
  let (frames, findings) = @moonmeter.validate_stream(bytes)
  println("frames found: " + frames.length().to_string())
  for f in frames {
    println(
      "  addr=" +
      @moonmeter.hex_encode(f.address) +
      " control=0x" +
      @moonmeter.hex_byte(f.control) +
      " data=" +
      @moonmeter.hex_encode(f.data),
    )
  }
  let (errors, warnings) = @moonmeter.count_findings(findings)
  println(
    "summary: " +
    errors.to_string() +
    " error(s), " +
    warnings.to_string() +
    " warning(s)",
  )
  if findings.length() > 0 {
    println("findings:")
  }
  for finding in findings {
    println(
      "  [" +
      finding.severity +
      " @ " +
      finding.offset.to_string() +
      " " +
      finding.code +
      "] " +
      finding.message,
    )
  }
  if findings.length() == 0 {
    println("all good")
  }
}

///|
fn cmd_read(addr_hex : String) -> Unit {
  let addr = match @moonmeter.hex_decode(addr_hex) {
    Some(a) => a
    None => {
      println("error: invalid address hex")
      return
    }
  }
  if addr.length() != 6 {
    println("error: address must be 6 bytes")
    return
  }
  let req = @moonmeter.build_read_request(addr, @moonmeter.di_active_total())
  println(@moonmeter.hex_encode(req))
}

///|
fn cmd_simulate(addr_hex : String, bad : Bool) -> Unit {
  let addr = match @moonmeter.hex_decode(addr_hex) {
    Some(a) => a
    None => {
      println("error: invalid address hex")
      return
    }
  }
  let sim = @moonmeter.MeterSim::new(addr)
  sim.set_reading(@moonmeter.di_active_total(), [0x56, 0x34, 0x12, 0x00])
  sim.set_reading(@moonmeter.di_voltage(), [0x00, 0x01])
  let stream = sim.generate_stream(bad)
  println(@moonmeter.hex_encode(stream))
}

///|
fn frame_error_label(err : @moonmeter.FrameError) -> String {
  match err {
    @moonmeter.FrameError::TooShort => "too short"
    @moonmeter.FrameError::BadStart => "bad start"
    @moonmeter.FrameError::BadEnd => "bad end"
    @moonmeter.FrameError::BadChecksum => "bad checksum"
    @moonmeter.FrameError::LengthMismatch => "length mismatch"
  }
}

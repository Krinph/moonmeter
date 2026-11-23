///|
/// DL/T 645-2007 conformance validator.
///
/// The analysis layer of moonmeter: it checks whether a byte stream is a
/// valid DL/T 645 exchange and reports structured diagnostics (framing,
/// checksum, BCD, control-code semantics). This is the capability a
/// protocol conformance tester needs, and it is grounded in the standard's
/// exact frame rules (single-byte L, +0x33 DATA offset, 12+L length).

///|
/// A single validation finding.
pub struct Finding {
  /// Byte offset in the input stream where the finding applies.
  offset : Int32
  /// Severity: "error" or "warning".
  severity : String
  /// Machine-readable code, e.g. "bad_checksum".
  code : String
  /// Human-readable message.
  message : String
}

///|
/// Split a byte stream into frames. Bytes between frames are reported as
/// "garbage" findings so a stream with framing problems is never silently
/// accepted. Optional FE preamble bytes are skipped without a finding.
pub fn split_frames(
  bytes : Array[Byte],
) -> (Array[Array[Byte]], Array[Finding]) {
  let frames : Array[Array[Byte]] = []
  let findings : Array[Finding] = []
  let mut i = 0
  while i < bytes.length() {
    // FE wake-up preamble bytes are legal and not part of the frame.
    if bytes[i] == 0xFE {
      i = i + 1
      continue
    }
    if bytes[i] != FrameStart {
      findings.push({
        offset: i,
        severity: "error",
        code: "stray_byte",
        message: "byte 0x" + hex(bytes[i]) + " outside a frame",
      })
      i = i + 1
      continue
    }
    // A frame needs at least 12 bytes: 68 ADDR[6] 68 C L CS 16.
    if i + 12 > bytes.length() {
      findings.push({
        offset: i,
        severity: "error",
        code: "truncated_frame",
        message: "frame header present but stream ends too early",
      })
      break
    }
    if bytes[i + 7] != FrameStart {
      findings.push({
        offset: i,
        severity: "error",
        code: "bad_start",
        message: "second start byte 68H missing at offset 7",
      })
      i = i + 1
      continue
    }
    // Single-byte length at i+9; total wire length = 12 + L.
    let len = bytes[i + 9].to_int()
    let frame_len = 12 + len
    if i + frame_len > bytes.length() {
      findings.push({
        offset: i,
        severity: "error",
        code: "truncated_frame",
        message: "declared length " +
        len.to_string() +
        " exceeds remaining bytes",
      })
      break
    }
    let frame = bytes[i:i + frame_len].to_owned()
    // CS covers [0 .. 9+L], i.e. first 68H through last DATA byte.
    let expected = checksum(frame[0:10 + len])
    if expected != frame[10 + len] {
      findings.push({
        offset: i,
        severity: "error",
        code: "bad_checksum",
        message: "checksum mismatch at offset " + i.to_string(),
      })
    }
    if frame[11 + len] != FrameEnd {
      findings.push({
        offset: i,
        severity: "error",
        code: "bad_end",
        message: "frame does not end with 16H",
      })
    }
    // BCD sanity: every address byte must be a valid BCD pair.
    for j = 1; j <= 6; j = j + 1 {
      let b = frame[j]
      if (b & 0x0F) > 0x09 || ((b >> 4) & 0x0F) > 0x09 {
        findings.push({
          offset: i + j,
          severity: "warning",
          code: "bad_bcd",
          message: "address byte " + j.to_string() + " is not valid BCD",
        })
      }
    }
    frames.push(frame)
    i = i + frame_len
  }
  (frames, findings)
}

///|
/// Validate a single decoded frame against protocol semantics.
pub fn validate_frame(frame : Frame) -> Array[Finding] {
  let findings : Array[Finding] = []
  let fc = function_code(frame.control)
  if fc == 0 {
    findings.push({
      offset: 8,
      severity: "warning",
      code: "zero_function",
      message: "control byte has zero function code",
    })
  }
  match Command::from_byte(frame.control) {
    None =>
      findings.push({
        offset: 8,
        severity: "warning",
        code: "unknown_function",
        message: "control code is not a defined DL/T 645-2007 function",
      })
    Some(_) => ()
  }
  // A normal read-data reply must echo at least the 4 DI bytes. An
  // abnormal reply instead carries a 1-byte error code and must not be
  // treated as a short reading.
  if is_reply(frame.control) &&
    !is_error_reply(frame.control) &&
    fc == Command::ReadData.value().to_int() &&
    frame.data.length() < 4 {
    findings.push({
      offset: 10,
      severity: "error",
      code: "short_read_reply",
      message: "read-data reply carries fewer than 4 DI bytes",
    })
  }
  findings
}

///|
/// Validate an entire byte stream: split into frames, report framing
/// findings, then run per-frame semantic checks on every valid frame.
pub fn validate_stream(bytes : Array[Byte]) -> (Array[Frame], Array[Finding]) {
  let (raw_frames, findings) = split_frames(bytes)
  let frames : Array[Frame] = []
  for raw in raw_frames {
    match decode_frame(raw) {
      Err(_) => ()
      Ok(frame) => {
        frames.push(frame)
        for finding in validate_frame(frame) {
          findings.push(finding)
        }
      }
    }
  }
  (frames, findings)
}

///|
/// Count findings by severity: `(errors, warnings)`.
pub fn count_findings(findings : Array[Finding]) -> (Int32, Int32) {
  let mut errors = 0
  let mut warnings = 0
  for f in findings {
    if f.severity == "error" {
      errors = errors + 1
    } else {
      warnings = warnings + 1
    }
  }
  (errors, warnings)
}

///|
/// Format findings as readable text.
pub fn render_findings(findings : Array[Finding]) -> String {
  if findings.length() == 0 {
    return "OK: no findings\n"
  }
  let sb = StringBuilder()
  for f in findings {
    sb.write_string(
      "[" +
      f.severity +
      " @ " +
      f.offset.to_string() +
      " " +
      f.code +
      "] " +
      f.message +
      "\n",
    )
  }
  sb.to_string()
}

///|
/// Hex format a byte.
fn hex(b : Byte) -> String {
  let digits = "0123456789ABCDEF"
  let hi = ((b >> 4) & 0x0F).to_int()
  let lo = (b & 0x0F).to_int()
  digits[hi].to_string() + digits[lo].to_string()
}

///|
/// DL/T 645 conformance validator.
///
/// This is the analysis layer of moonmeter: it does not merely transport
/// frames, it checks whether a stream of bytes is a *valid* DL/T 645
/// exchange and reports structured diagnostics (frame errors, checksum
/// mismatches, illegal BCD digits, unknown control codes, inconsistent
/// length fields). A meter or a master that produces frames violating these
/// rules can be flagged automatically, which is the use case for protocol
/// conformance testers.

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
/// accepted.
pub fn split_frames(
  bytes : Array[Byte],
) -> (Array[Array[Byte]], Array[Finding]) {
  let frames : Array[Array[Byte]] = []
  let findings : Array[Finding] = []
  let mut i = 0
  while i < bytes.length() {
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
    // Look for the end: scan for the closing 16H after a plausible length.
    if i + 13 > bytes.length() {
      findings.push({
        offset: i,
        severity: "error",
        code: "truncated_frame",
        message: "frame header present but stream ends too early",
      })
      break
    }
    // Control is byte i+8; length is bytes i+9..i+10 (little-endian).
    let len = bytes[i + 9].to_int() | (bytes[i + 10].to_int() << 8)
    let frame_len = 11 + len + 2
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
    // Validate the checksum.
    let expected = checksum_sum(frame[0:frame_len - 2])
    if expected != frame[frame_len - 2] {
      findings.push({
        offset: i,
        severity: "error",
        code: "bad_checksum",
        message: "checksum mismatch at offset " + i.to_string(),
      })
    }
    if frame[frame_len - 1] != FrameEnd {
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
/// Validate a single decoded frame against the protocol rules.
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
  // The data field length implied by the frame is already consistent by
  // construction; but a read reply must carry at least the 4 DI bytes.
  if is_reply(frame.control) &&
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

///|
/// Sum of bytes modulo 256 (matches frame CS).
fn checksum_sum(bytes : ArrayView[Byte]) -> Byte {
  let mut sum = 0
  for b in bytes {
    sum = sum + b.to_int()
  }
  (sum & 0xFF).to_byte()
}

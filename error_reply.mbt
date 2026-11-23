///|
/// DL/T 645-2007 abnormal-reply (error) decoding.
///
/// When a meter cannot serve a request it sends a slave reply (D7=1) with
/// the abnormal flag set (D6=1). For a read-data request that control byte
/// is 0xD1, NOT 0xC1. The DATA field carries a one-byte error information
/// code; like all DATA it arrives offset by +0x33 and is restored by
/// `decode_frame` before this module sees it.

///|
/// Error information codes carried in an abnormal reply's DATA field.
pub enum ErrorCode {
  PasswordError
  ControlCodeError
  DataIdError
  DataLengthError
  AddressError
  OtherError
  Unknown
}

///|
/// Decode an error information byte into a structured `ErrorCode`.
/// Unrecognised values map to `Unknown` rather than being dropped.
pub fn ErrorCode::from_byte(b : Byte) -> ErrorCode {
  match b.to_int() {
    0x01 => PasswordError
    0x02 => ControlCodeError
    0x03 => DataIdError
    0x04 => DataLengthError
    0x05 => AddressError
    0x06 => OtherError
    _ => Unknown
  }
}

///|
/// A short human-readable description of an error code.
pub fn ErrorCode::label(self : ErrorCode) -> String {
  match self {
    PasswordError => "password error"
    ControlCodeError => "control code error"
    DataIdError => "data identifier error"
    DataLengthError => "data length error"
    AddressError => "address error"
    OtherError => "other error"
    Unknown => "unknown error code"
  }
}

///|
/// Extract the error information code from a decoded frame.
/// Returns `None` unless the frame is a genuine abnormal slave reply
/// (D7=1 and D6=1) that carries at least one DATA byte.
pub fn decode_error_reply(frame : Frame) -> ErrorCode? {
  if !is_error_reply(frame.control) || frame.data.length() == 0 {
    return None
  }
  Some(ErrorCode::from_byte(frame.data[0]))
}

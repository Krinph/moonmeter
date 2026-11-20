///|
/// DL/T 645-2007 error-reply decoding.
///
/// When a meter cannot serve a request it sets the error direction bit (0x40)
/// in the control byte and returns a single error code in the first data byte.
/// `moonmeter` already exposes `is_error_reply`; this module turns that signal
/// into a structured, human-readable `ErrorCode`.

///|
/// Standard DL/T 645 error codes carried in an error reply's data field.
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
/// Decode an error byte into a structured `ErrorCode`.
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
/// Extract the error code from a decoded frame.
/// Returns `None` unless the frame is an error reply that carries a code byte.
pub fn decode_error_reply(frame : Frame) -> ErrorCode? {
  if !is_error_reply(frame.control) || frame.data.length() == 0 {
    return None
  }
  Some(ErrorCode::from_byte(frame.data[0]))
}

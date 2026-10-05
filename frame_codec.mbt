///|
/// Explicit physical/raw/label assignment; never infer meaning from a number.
pub(all) enum SignalValue {
  Physical(Double)
  Raw(RawValue)
  Label(String)
} derive(Eq, @debug.Debug)

///|
/// One named input assignment.
pub(all) struct SignalAssignment {
  name : String
  value : SignalValue
} derive(Eq, @debug.Debug)

///|
/// Decoded data preserves exact raw values and reports physical range violations.
pub(all) struct DecodedSignal {
  name : String
  raw : RawValue
  physical : Double
  unit : String
  label : String?
  out_of_range : Bool
} derive(Eq, @debug.Debug)

///|
/// A selected message and only its currently active signals.
pub(all) struct DecodedMessage {
  name : String
  frame_id : FrameId
  signals : Array[DecodedSignal]
  diagnostics : Array[Diagnostic]
} derive(Eq, @debug.Debug)

///|
/// Encoded frame and warnings (range policy and unknown mux).
pub(all) struct EncodedMessage {
  frame : CanFrame
  diagnostics : Array[Diagnostic]
} derive(Eq, @debug.Debug)

///|
/// Validated snapshot with cached bit coordinates for repeated frame processing.
pub struct CompiledMessage {
  message : Message
  positions : Array[Array[Int]]
  selector : Int?
}

///|
/// Validate codec semantics once and snapshot mutable arrays before reuse.
pub fn compile_message(message : Message) -> CompiledMessage raise DbcError {
  let findings = []
  validate_message(message, Database::new(), findings, check_nodes=false)
  for d in findings {
    if d.severity == Error {
      raise Failure(d)
    }
  }
  ignore(FrameId::new(message.frame_id.id, extended=message.frame_id.extended))
  if message.raw_dbc_id != message.frame_id.to_dbc() {
    fail("message.raw_id", "inconsistent frame identity")
  }
  let signals = message.signals.map(fn(s) {
    Signal::{ ..s, values: s.values.copy(), receivers: s.receivers.copy() }
  })
  let snapshot = Message::{ ..message, signals, }
  let positions = []
  let mut selector = None
  for i, s in signals {
    positions.push(signal_bits(s, message.length))
    if s.multiplex == Multiplexer {
      selector = Some(i)
    }
  }
  { message: snapshot, positions, selector }
}

///|
fn raw_from_positions(
  s : Signal,
  payload : Array[Byte],
  positions : Array[Int],
) -> RawValue {
  let bits = match s.byte_order {
    Intel => extract_intel(payload, positions)
    Motorola => extract_motorola(payload, positions)
  }
  if !s.signed {
    return Unsigned(bits)
  }
  if s.bit_length == 64 {
    return Signed(bits.reinterpret_as_int64())
  }
  let extended = if (bits & (1UL << (s.bit_length - 1))) != 0UL {
    bits | (0xFFFFFFFFFFFFFFFFUL << s.bit_length)
  } else {
    bits
  }
  Signed(extended.reinterpret_as_int64())
}

///|
fn branch_active(mux : MultiplexInfo, selector : UInt64?) -> Bool {
  match mux {
    Always | Multiplexer => true
    Branch(n) =>
      match selector {
        Some(v) => n >= 0L && n.reinterpret_as_uint64() == v
        None => false
      }
  }
}

///|
fn unknown_mux(message : Message, selector : UInt64?) -> Bool {
  let mut branches = false
  let mut known = false
  for s in message.signals {
    if s.multiplex is Branch(_) {
      branches = true
      if branch_active(s.multiplex, selector) {
        known = true
      }
    }
  }
  branches && !known
}

///|
fn enum_label(signal : Signal, raw : RawValue) -> String? {
  for v in signal.values {
    let matches = match raw {
      Signed(n) => n == v.raw
      Unsigned(n) => v.raw >= 0L && n == v.raw.reinterpret_as_uint64()
    }
    if matches {
      return Some(v.label)
    }
  }
  None
}

///|
/// Decode using cached layout. Payload length and frame kind must match exactly.
pub fn CompiledMessage::decode(
  self : CompiledMessage,
  frame : CanFrame,
) -> DecodedMessage raise DbcError {
  let m = self.message
  if frame.frame_id != m.frame_id {
    fail("codec.frame_id", "frame identity does not match message")
  }
  if frame.payload.length() != m.length {
    fail(
      "codec.payload_length", "payload length must exactly match database message",
    )
  }
  let selector = match self.selector {
    Some(i) =>
      match raw_from_positions(m.signals[i], frame.payload, self.positions[i]) {
        Unsigned(v) => Some(v)
        Signed(_) => None
      }
    None => None
  }
  let signals = []
  let diagnostics = []
  if unknown_mux(m, selector) {
    diagnostics.push(
      diagnostic(
        "mux.unknown",
        "selector has no defined branch",
        message_name=Some(m.name),
        severity=Warning,
      ),
    )
  }
  for i, s in m.signals {
    if !branch_active(s.multiplex, selector) {
      continue
    }
    let raw = raw_from_positions(s, frame.payload, self.positions[i])
    let physical = raw_to_physical(s, raw)
    let out_of_range = physical < s.minimum || physical > s.maximum
    if out_of_range {
      diagnostics.push(
        diagnostic(
          "codec.decoded_range",
          "decoded physical value exceeds declared range",
          message_name=Some(m.name),
          signal_name=Some(s.name),
          severity=Warning,
        ),
      )
    }
    signals.push({
      name: s.name,
      raw,
      physical,
      unit: s.unit,
      label: enum_label(s, raw),
      out_of_range,
    })
  }
  { name: m.name, frame_id: m.frame_id, signals, diagnostics }
}

///|
fn assignment_raw(
  s : Signal,
  value : SignalValue,
  policy : RangePolicy,
  diagnostics : Array[Diagnostic],
) -> RawValue raise DbcError {
  match value {
    Raw(raw) => {
      ignore(checked_raw_bits(s, raw))
      raw
    }
    Physical(v) => {
      let raw = physical_to_raw(s, v, range_policy=policy)
      if policy == Warn &&
        (
          v < s.minimum ||
          v > s.maximum ||
          raw_to_physical(s, raw) < s.minimum ||
          raw_to_physical(s, raw) > s.maximum
        ) {
        diagnostics.push(
          diagnostic(
            "codec.encoded_range",
            "physical assignment exceeds declared range",
            signal_name=Some(s.name),
            severity=Warning,
          ),
        )
      }
      raw
    }
    Label(label) => {
      for v in s.values {
        if v.label == label {
          let raw = if s.signed {
            Signed(v.raw)
          } else {
            Unsigned(v.raw.reinterpret_as_uint64())
          }
          ignore(checked_raw_bits(s, raw))
          return raw
        }
      }
      fail("codec.label", "unknown enumeration label \{label}")
      Unsigned(0UL)
    }
  }
}

///|
/// Encode all active signals; inactive, duplicate, missing and unknown inputs fail.
/// Unoccupied payload bits are zero. Raw inputs bypass physical range policy.
pub fn CompiledMessage::encode(
  self : CompiledMessage,
  assignments : Array[SignalAssignment],
  range_policy? : RangePolicy = Reject,
) -> EncodedMessage raise DbcError {
  let m = self.message
  let inputs : Map[String, SignalValue] = Map([])
  let diagnostics = []
  for a in assignments {
    if m.signal_by_name(a.name) is None {
      fail("codec.unknown_signal", "unknown signal \{a.name}")
    }
    if inputs.contains(a.name) {
      fail("codec.duplicate_input", "duplicate signal \{a.name}")
    }
    inputs[a.name] = a.value
  }
  let selector = match self.selector {
    Some(i) => {
      let s = m.signals[i]
      let value = match inputs.get(s.name) {
        Some(v) => v
        None => {
          fail("codec.missing_input", "missing selector \{s.name}")
          Raw(Unsigned(0UL))
        }
      }
      match assignment_raw(s, value, range_policy, diagnostics) {
        Unsigned(n) => Some(n)
        Signed(_) => None
      }
    }
    None => None
  }
  if unknown_mux(m, selector) {
    diagnostics.push(
      diagnostic(
        "mux.unknown",
        "selector has no defined branch",
        message_name=Some(m.name),
        severity=Warning,
      ),
    )
  }
  let payload : Array[Byte] = Array::make(m.length, 0)
  for s in m.signals {
    if !branch_active(s.multiplex, selector) {
      if inputs.contains(s.name) {
        fail(
          "codec.inactive_input",
          "assignment belongs to inactive branch: \{s.name}",
        )
      }
      continue
    }
    let value = match inputs.get(s.name) {
      Some(v) => v
      None => {
        fail("codec.missing_input", "missing active signal \{s.name}")
        Raw(Unsigned(0UL))
      }
    }
    let raw = assignment_raw(s, value, range_policy, diagnostics)
    encode_signal_raw(s, payload, raw)
  }
  { frame: { frame_id: m.frame_id, payload }, diagnostics }
}

///|
/// Look up the frame identity in a database and decode its active signals.
pub fn decode_frame(
  db : Database,
  frame : CanFrame,
) -> DecodedMessage raise DbcError {
  let message = match db.message_by_id(frame.frame_id) {
    Some(m) => m
    None => {
      fail("codec.unknown_id", "unknown frame identity")
      return {
        name: "",
        frame_id: frame.frame_id,
        signals: [],
        diagnostics: [],
      }
    }
  }
  compile_message(message).decode(frame)
}

///|
/// Encode a semantic message with explicit signal values and range policy.
pub fn encode_message(
  message : Message,
  assignments : Array[SignalAssignment],
  range_policy? : RangePolicy = Reject,
) -> EncodedMessage raise DbcError {
  compile_message(message).encode(assignments, range_policy~)
}

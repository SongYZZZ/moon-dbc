///|
/// Severity of a diagnostic; warnings do not invalidate a database.
pub(all) enum Severity {
  Error
  Warning
} derive(Eq, @debug.Debug)

///|
/// One-based line/column and zero-based UTF-16 code-unit offset.
pub(all) struct SourceLocation {
  line : Int
  column : Int
  offset : Int
} derive(Eq, @debug.Debug)

///|
/// Stable code, readable explanation and source/object context.
pub(all) struct Diagnostic {
  severity : Severity
  code : String
  message : String
  location : SourceLocation
  message_name : String?
  signal_name : String?
} derive(Eq, @debug.Debug)

///|
/// Parsing and codec failures carry the same structured diagnostic format.
pub suberror DbcError {
  Failure(Diagnostic)
} derive(@debug.Debug)

///|
fn diagnostic(
  code : String,
  message : String,
  location? : SourceLocation = { line: 0, column: 0, offset: 0 },
  message_name? : String? = None,
  signal_name? : String? = None,
  severity? : Severity = Error,
) -> Diagnostic {
  { severity, code, message, location, message_name, signal_name }
}

///|
fn fail(code : String, message : String) -> Unit raise DbcError {
  raise Failure(diagnostic(code, message))
}

///|
/// Intel's start is the LSB; Motorola's start is the MSB (DBC sawtooth).
pub(all) enum ByteOrder {
  Intel
  Motorola
} derive(Eq, @debug.Debug)

///|
/// Basic multiplexing: one unsigned selector and equality-selected branches.
pub(all) enum MultiplexInfo {
  Always
  Multiplexer
  Branch(Int64)
} derive(Eq, @debug.Debug)

///|
/// Encoding range behavior. Reject is the default; Clamp is always explicit.
pub(all) enum RangePolicy {
  Ignore
  Warn
  Reject
  Clamp
} derive(Eq, @debug.Debug)

///|
/// Strict rejects unknown statements; permissive preserves noncritical ones.
pub(all) enum ParseMode {
  Strict
  Permissive
} derive(Eq, @debug.Debug)

///|
/// Normalized arbitration ID, with frame kind participating in identity.
pub(all) struct FrameId {
  id : UInt
  extended : Bool
} derive(Eq, @debug.Debug)

///|
/// Create a checked standard (11-bit) or extended (29-bit) identifier.
pub fn FrameId::new(
  id : UInt,
  extended? : Bool = false,
) -> FrameId raise DbcError {
  if id > (if extended { 0x1FFFFFFFU } else { 0x7FFU }) {
    fail("id.range", "arbitration ID exceeds frame kind")
  }
  { id, extended }
}

///|
/// Interpret bit 31 as DBC's extended-ID flag; bits 29/30 are rejected.
pub fn frame_id_from_dbc(raw : UInt) -> FrameId raise DbcError {
  if (raw & 0x60000000U) != 0U {
    fail("id.flags", "unsupported DBC identifier flags")
  }
  FrameId::new(raw & 0x1FFFFFFFU, extended=(raw & 0x80000000U) != 0U)
}

///|
/// Convert a normalized ID to its conventional DBC representation.
pub fn FrameId::to_dbc(self : FrameId) -> UInt {
  self.id | (if self.extended { 0x80000000U } else { 0U })
}

///|
/// Exact raw values retain all 64 bits; doubles are reserved for physical data.
pub(all) enum RawValue {
  Unsigned(UInt64)
  Signed(Int64)
} derive(Eq, @debug.Debug)

///|
/// Named raw value, independent of factor/offset.
pub(all) struct ValueDescription {
  raw : Int64
  label : String
} derive(Eq, @debug.Debug)

///|
/// A participant in the database's network topology.
pub(all) struct Node {
  name : String
  location : SourceLocation
} derive(Eq, @debug.Debug)

///|
/// Integer DBC signal with complete core layout/scaling metadata.
pub(all) struct Signal {
  name : String
  start_bit : Int
  bit_length : Int
  byte_order : ByteOrder
  signed : Bool
  factor : Double
  offset : Double
  minimum : Double
  maximum : Double
  unit : String
  receivers : Array[String]
  multiplex : MultiplexInfo
  values : Array[ValueDescription]
  location : SourceLocation
} derive(Eq, @debug.Debug)

///|
/// Define a signal; semantic validation remains available for programmatic models.
pub fn Signal::new(
  name : String,
  start_bit : Int,
  bit_length : Int,
  byte_order? : ByteOrder = Intel,
  signed? : Bool = false,
  factor? : Double = 1.0,
  offset? : Double = 0.0,
  minimum? : Double = 0.0,
  maximum? : Double = 0.0,
  unit? : String = "",
  receivers? : Array[String] = [],
  multiplex? : MultiplexInfo = Always,
) -> Signal {
  {
    name,
    start_bit,
    bit_length,
    byte_order,
    signed,
    factor,
    offset,
    minimum,
    maximum,
    unit,
    receivers,
    multiplex,
    values: [],
    location: { line: 0, column: 0, offset: 0 },
  }
}

///|
/// DBC payload length is bytes, not a transport DLC code.
pub(all) struct Message {
  raw_dbc_id : UInt
  frame_id : FrameId
  name : String
  length : Int
  transmitter : String
  signals : Array[Signal]
  location : SourceLocation
} derive(Eq, @debug.Debug)

///|
/// Construct an in-memory message retaining its conventional DBC ID.
pub fn Message::new(
  frame_id : FrameId,
  name : String,
  length : Int,
  transmitter? : String = "Vector__XXX",
  signals? : Array[Signal] = [],
) -> Message {
  {
    raw_dbc_id: frame_id.to_dbc(),
    frame_id,
    name,
    length,
    transmitter,
    signals,
    location: { line: 0, column: 0, offset: 0 },
  }
}

///|
/// Scope of attributes; object references use original DBC IDs.
pub(all) enum Scope {
  DatabaseScope
  NodeScope
  MessageScope
  SignalScope
} derive(Eq, @debug.Debug)

///|
/// Object addressed by comments or attributes.
pub(all) enum ObjectRef {
  DatabaseRef
  NodeRef(String)
  MessageRef(UInt)
  SignalRef(UInt, String)
} derive(Eq, Hash, @debug.Debug)

///|
/// Typed attribute grammar; bounds are physical numeric bounds.
pub(all) enum AttributeType {
  IntType(Int64, Int64)
  HexType(Int64, Int64)
  FloatType(Double, Double)
  StringType
  EnumType(Array[String])
} derive(Eq, @debug.Debug)

///|
/// Attribute data; enum assignments are zero-based integer indices.
pub(all) enum AttributeValue {
  Integer(Int64)
  Real(Double)
  Text(String)
} derive(Eq, @debug.Debug)

///|
/// Attribute schema and scope.
pub(all) struct AttributeDefinition {
  name : String
  scope : Scope
  kind : AttributeType
  location : SourceLocation
} derive(Eq, @debug.Debug)

///|
/// Attribute assignment/default (None denotes a default).
pub(all) struct Attribute {
  name : String
  target : ObjectRef?
  value : AttributeValue
  location : SourceLocation
} derive(Eq, @debug.Debug)

///|
/// Database, node, message or signal comment, preserving UTF-8 text.
pub(all) struct Comment {
  target : ObjectRef
  text : String
  location : SourceLocation
} derive(Eq, @debug.Debug)

///|
/// Preserved permissive-mode extension with an explicit warning.
pub(all) struct UnsupportedStatement {
  keyword : String
  text : String
  location : SourceLocation
} derive(Eq, @debug.Debug)

///|
/// Semantic database; parsing implementation details are private.
pub(all) struct Database {
  mut version : String
  nodes : Array[Node]
  messages : Array[Message]
  comments : Array[Comment]
  attribute_definitions : Array[AttributeDefinition]
  attributes : Array[Attribute]
  unsupported : Array[UnsupportedStatement]
  diagnostics : Array[Diagnostic]
}

///|
/// Create an empty semantic database.
pub fn Database::new() -> Database {
  {
    version: "",
    nodes: [],
    messages: [],
    comments: [],
    attribute_definitions: [],
    attributes: [],
    unsupported: [],
    diagnostics: [],
  }
}

///|
/// Query an ID with frame kind (standard and extended IDs may coexist).
pub fn Database::message_by_id(self : Database, id : FrameId) -> Message? {
  for m in self.messages {
    if m.frame_id == id {
      return Some(m)
    }
  }
  None
}

///|
/// Query a message name.
pub fn Database::message_by_name(self : Database, name : String) -> Message? {
  for m in self.messages {
    if m.name == name {
      return Some(m)
    }
  }
  None
}

///|
/// Query a declared node.
pub fn Database::node_by_name(self : Database, name : String) -> Node? {
  for n in self.nodes {
    if n.name == name {
      return Some(n)
    }
  }
  None
}

///|
/// Query a signal within a message.
pub fn Message::signal_by_name(self : Message, name : String) -> Signal? {
  for s in self.signals {
    if s.name == name {
      return Some(s)
    }
  }
  None
}

///|
/// Search signals across messages, returning their containing message too.
pub fn Database::find_signals(
  self : Database,
  name : String,
) -> Array[(Message, Signal)] {
  let found = []
  for m in self.messages {
    for s in m.signals {
      if s.name == name {
        found.push((m, s))
      }
    }
  }
  found
}

///|
/// In-memory frame; hardware IO is deliberately outside the library.
pub(all) struct CanFrame {
  frame_id : FrameId
  payload : Array[Byte]
} derive(Eq, @debug.Debug)

///|
/// Parsed input resource budgets. All lengths use UTF-16 code units.
pub(all) struct ParseLimits {
  max_file_size : Int
  max_line_length : Int
  max_token_length : Int
  max_name_length : Int
  max_messages : Int
  max_signals_per_message : Int
  max_total_signals : Int
  max_attribute_size : Int
  max_nodes : Int
  max_tokens : Int
  max_metadata_records : Int
} derive(Eq, @debug.Debug)

///|
/// Conservative defaults for untrusted input, including 10,000 signals.
pub fn ParseLimits::default() -> ParseLimits {
  {
    max_file_size: 16 * 1024 * 1024,
    max_line_length: 65536,
    max_token_length: 65536,
    max_name_length: 128,
    max_messages: 10000,
    max_signals_per_message: 512,
    max_total_signals: 100000,
    max_attribute_size: 65536,
    max_nodes: 10000,
    max_tokens: 2000000,
    max_metadata_records: 100000,
  }
}

///|
/// Mode and explicit resource policy.
pub(all) struct ParseOptions {
  mode : ParseMode
  limits : ParseLimits
} derive(Eq, @debug.Debug)

///|
/// Strict parsing with bounded inputs.
pub fn ParseOptions::default() -> ParseOptions {
  { mode: Strict, limits: ParseLimits::default() }
}

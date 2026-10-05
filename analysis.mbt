///|
/// Database inventory, with message byte length separated from transport semantics.
pub(all) struct DatabaseStats {
  nodes : Int
  messages : Int
  signals : Int
  standard_messages : Int
  extended_messages : Int
  classic_sized_messages : Int
  fd_sized_messages : Int
  multiplexed_messages : Int
  value_descriptions : Int
  errors : Int
  warnings : Int
} derive(Eq, @debug.Debug)

///|
/// Count semantic objects and actual validation findings.
pub fn inspect_database(db : Database) -> DatabaseStats {
  let mut signals = 0
  let mut extended = 0
  let mut fd = 0
  let mut mux = 0
  let mut values = 0
  for m in db.messages {
    if m.frame_id.extended {
      extended += 1
    }
    if m.length > 8 {
      fd += 1
    }
    if m.signals.iter().any(fn(s) { s.multiplex == Multiplexer }) {
      mux += 1
    }
    signals += m.signals.length()
    for s in m.signals {
      values += s.values.length()
    }
  }
  let diagnostics = validate_database(db)
  let errors = diagnostics.filter(fn(d) { d.severity == Error }).length()
  {
    nodes: db.nodes.length(),
    messages: db.messages.length(),
    signals,
    standard_messages: db.messages.length() - extended,
    extended_messages: extended,
    classic_sized_messages: db.messages.length() - fd,
    fd_sized_messages: fd,
    multiplexed_messages: mux,
    value_descriptions: values,
    errors,
    warnings: diagnostics.length() - errors,
  }
}

///|
/// Occupancy of one payload bit; multiple exclusive branch owners are retained.
pub(all) struct BitCell {
  position : Int
  owners : Array[String]
} derive(Eq, @debug.Debug)

///|
/// Compute a real bit layout for 0..64 bytes without hardcoded demo coordinates.
pub fn message_layout(message : Message) -> Array[BitCell] raise DbcError {
  if message.length < 0 || message.length > 64 {
    fail("message.length", "payload must be 0..64 bytes")
  }
  let cells = Array::makei(message.length * 8, fn(position) {
    BitCell::{ position, owners: [] }
  })
  for s in message.signals {
    let tag = match s.multiplex {
      Always => s.name
      Multiplexer => s.name + "(M)"
      Branch(n) => s.name + "(m\{n})"
    }
    for bit in signal_bits(s, message.length) {
      cells[bit].owners.push(tag)
    }
  }
  cells
}

///|
/// Display each byte from bit 7 through bit 0; '.' denotes unoccupied bits.
pub fn render_layout(message : Message) -> String raise DbcError {
  let cells = message_layout(message)
  let lines = [
    "Message: \{message.name} ID: \{message.raw_dbc_id} Length: \{message.length}",
    "Bits per byte: 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0",
  ]
  for byte = 0; byte < message.length; byte = byte + 1 {
    let columns = []
    for bit = 7; bit >= 0; bit = bit - 1 {
      let owners = cells[byte * 8 + bit].owners
      columns.push(if owners.length() == 0 { "." } else { owners.join("/") })
    }
    lines.push("Byte \{byte}: " + columns.join(" | "))
  }
  lines.join("\n")
}

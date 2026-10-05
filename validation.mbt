///|
/// Collect all semantic errors without throwing, including multiplex-aware overlaps.
pub fn validate_database(db : Database) -> Array[Diagnostic] {
  let out = db.diagnostics.copy()
  let node_names : Map[String, Bool] = Map([])
  for n in db.nodes {
    if node_names.contains(n.name) {
      out.push(
        diagnostic(
          "node.duplicate",
          "duplicate node \{n.name}",
          location=n.location,
        ),
      )
    }
    if !valid_name(n.name) {
      out.push(
        diagnostic("node.name", "invalid node name", location=n.location),
      )
    }
    node_names[n.name] = true
  }
  let message_ids : Map[UInt, Bool] = Map([])
  let message_names : Map[String, Bool] = Map([])
  for m in db.messages {
    if message_ids.contains(m.frame_id.to_dbc()) {
      out.push(
        message_diagnostic(
          m, "message.duplicate_id", "duplicate frame identity",
        ),
      )
    }
    if message_names.contains(m.name) {
      out.push(
        message_diagnostic(
          m, "message.duplicate_name", "duplicate message name",
        ),
      )
    }
    message_ids[m.frame_id.to_dbc()] = true
    message_names[m.name] = true
    if !valid_name(m.name) {
      out.push(message_diagnostic(m, "message.name", "invalid message name"))
    }
    try FrameId::new(m.frame_id.id, extended=m.frame_id.extended) catch {
      Failure(d) => out.push(message_diagnostic(m, d.code, d.message))
    } noraise {
      _ => ()
    }
    if m.raw_dbc_id != m.frame_id.to_dbc() {
      out.push(
        message_diagnostic(
          m, "message.raw_id", "raw DBC ID differs from normalized ID",
        ),
      )
    }
    if !known_node(db, m.transmitter) {
      out.push(
        message_diagnostic(
          m,
          "message.transmitter",
          "unknown transmitter \{m.transmitter}",
        ),
      )
    }
    validate_message(m, db, out)
  }
  for c in db.comments {
    if !object_exists(db, c.target) {
      out.push(
        diagnostic(
          "comment.target",
          "comment references unknown object",
          location=c.location,
        ),
      )
    }
  }
  validate_attributes(db, out)
  out
}

///|
fn known_node(db : Database, name : String) -> Bool {
  name == "Vector__XXX" || db.node_by_name(name) is Some(_)
}

///|
fn message_diagnostic(m : Message, code : String, text : String) -> Diagnostic {
  diagnostic(code, text, location=m.location, message_name=Some(m.name))
}

///|
fn signal_diagnostic(
  m : Message,
  s : Signal,
  code : String,
  text : String,
) -> Diagnostic {
  diagnostic(
    code,
    text,
    location=s.location,
    message_name=Some(m.name),
    signal_name=Some(s.name),
  )
}

///|
fn validate_message(
  m : Message,
  db : Database,
  out : Array[Diagnostic],
) -> Unit {
  if m.length < 0 || m.length > 64 {
    out.push(
      message_diagnostic(m, "message.length", "payload must be 0..64 bytes"),
    )
    return
  }
  let names : Map[String, Bool] = Map([])
  let owners : Array[Array[Int]] = Array::makei(m.length * 8, fn(_) { [] })
  let overlap_pairs : Map[(Int, Int), Bool] = Map([])
  let mut selectors = 0
  let mut branches = 0
  let mut selector : Signal? = None
  for i, s in m.signals {
    if names.contains(s.name) {
      out.push(
        signal_diagnostic(m, s, "signal.duplicate", "duplicate signal name"),
      )
    }
    names[s.name] = true
    if !valid_name(s.name) {
      out.push(signal_diagnostic(m, s, "signal.name", "invalid signal name"))
    }
    if !finite(s.factor) || s.factor == 0.0 || !finite(s.offset) {
      out.push(
        signal_diagnostic(
          m, s, "signal.factor", "factor must be finite and nonzero; offset finite",
        ),
      )
    }
    if !finite(s.minimum) || !finite(s.maximum) || s.minimum > s.maximum {
      out.push(
        signal_diagnostic(m, s, "signal.range", "invalid physical range"),
      )
    }
    for receiver in s.receivers {
      if !known_node(db, receiver) {
        out.push(
          signal_diagnostic(
            m,
            s,
            "signal.receiver",
            "unknown receiver \{receiver}",
          ),
        )
      }
    }
    match s.multiplex {
      Multiplexer => {
        selectors += 1
        selector = Some(s)
        if s.signed {
          out.push(
            signal_diagnostic(
              m, s, "mux.signed", "multiplex selector must be unsigned",
            ),
          )
        }
      }
      Branch(n) => {
        branches += 1
        if n < 0L {
          out.push(
            signal_diagnostic(m, s, "mux.branch", "negative multiplex branch"),
          )
        }
      }
      Always => ()
    }
    try signal_bits(s, m.length) catch {
      Failure(d) => out.push(signal_diagnostic(m, s, d.code, d.message))
    } noraise {
      bits =>
        for bit in bits {
          for j in owners[bit] {
            let other = m.signals[j]
            if active_together(s.multiplex, other.multiplex) &&
              !overlap_pairs.contains((j, i)) {
              overlap_pairs[(j, i)] = true
              out.push(
                signal_diagnostic(
                  m,
                  s,
                  "signal.overlap",
                  "overlap with \{other.name} at bit \{bit}",
                ),
              )
            }
          }
          owners[bit].push(i)
        }
    }
    let raw_values : Map[Int64, Bool] = Map([])
    let labels : Map[String, Bool] = Map([])
    for v in s.values {
      if raw_values.contains(v.raw) {
        out.push(
          signal_diagnostic(
            m, s, "values.duplicate", "duplicate raw enumeration value",
          ),
        )
      }
      if labels.contains(v.label) {
        out.push(
          signal_diagnostic(m, s, "values.label", "duplicate enumeration label"),
        )
      }
      raw_values[v.raw] = true
      labels[v.label] = true
      if !integer_fits(s, v.raw) {
        out.push(
          signal_diagnostic(
            m, s, "values.range", "enumeration is outside signal raw range",
          ),
        )
      }
    }
  }
  if selectors > 1 {
    out.push(
      message_diagnostic(
        m, "mux.multiple", "basic multiplexing permits one selector",
      ),
    )
  }
  if branches > 0 && selectors == 0 {
    out.push(
      message_diagnostic(m, "mux.missing", "branch signals require a selector"),
    )
  }
  if selector is Some(sel) {
    for s in m.signals {
      if s.multiplex is Branch(n) && !integer_fits(sel, n) {
        out.push(
          signal_diagnostic(
            m, s, "mux.range", "branch value does not fit selector",
          ),
        )
      }
    }
  }
}

///|
fn integer_fits(s : Signal, raw : Int64) -> Bool {
  if s.bit_length < 1 || s.bit_length > 64 {
    return false
  }
  if s.signed {
    if s.bit_length == 64 {
      return true
    }
    let limit = 1L << (s.bit_length - 1)
    raw >= -limit && raw < limit
  } else {
    raw >= 0L && (s.bit_length >= 63 || raw < 1L << s.bit_length)
  }
}

///|
fn object_exists(db : Database, target : ObjectRef) -> Bool {
  match target {
    DatabaseRef => true
    NodeRef(n) => db.node_by_name(n) is Some(_)
    MessageRef(id) => db.messages.iter().any(fn(m) { m.raw_dbc_id == id })
    SignalRef(id, n) =>
      db.messages
      .iter()
      .any(fn(m) { m.raw_dbc_id == id && m.signal_by_name(n) is Some(_) })
  }
}

///|
fn validate_attributes(db : Database, out : Array[Diagnostic]) -> Unit {
  let defs : Map[String, AttributeDefinition] = Map([])
  for d in db.attribute_definitions {
    if defs.contains(d.name) {
      out.push(
        diagnostic(
          "attribute.duplicate_definition",
          "duplicate attribute definition",
          location=d.location,
        ),
      )
    }
    defs[d.name] = d
    let valid = match d.kind {
      IntType(lo, hi) | HexType(lo, hi) => lo <= hi
      FloatType(lo, hi) => finite(lo) && finite(hi) && lo <= hi
      EnumType(choices) =>
        choices.length() > 0 &&
        choices
        .iter()
        .all(fn(c) { choices.filter(fn(x) { x == c }).length() == 1 })
      StringType => true
    }
    if !valid {
      out.push(
        diagnostic(
          "attribute.definition",
          "invalid attribute bounds or enum choices",
          location=d.location,
        ),
      )
    }
  }
  let seen : Map[(String, ObjectRef?), Bool] = Map([])
  for a in db.attributes {
    if seen.contains((a.name, a.target)) {
      out.push(
        diagnostic(
          "attribute.duplicate_assignment",
          "duplicate attribute assignment/default",
          location=a.location,
        ),
      )
    }
    seen[(a.name, a.target)] = true
    if a.target is Some(target) && !object_exists(db, target) {
      out.push(
        diagnostic(
          "attribute.target",
          "unknown attribute object",
          location=a.location,
        ),
      )
    }
    match defs.get(a.name) {
      None =>
        out.push(
          diagnostic(
            "attribute.undefined",
            "attribute has no definition",
            location=a.location,
          ),
        )
      Some(d) => {
        if a.target is Some(target) && object_scope(target) != d.scope {
          out.push(
            diagnostic(
              "attribute.scope",
              "attribute assignment uses wrong scope",
              location=a.location,
            ),
          )
        }
        if !attribute_value_valid(d.kind, a.value) {
          out.push(
            diagnostic(
              "attribute.value",
              "attribute value/default violates type or bounds",
              location=a.location,
            ),
          )
        }
      }
    }
  }
}

///|
fn attribute_value_valid(kind : AttributeType, value : AttributeValue) -> Bool {
  match (kind, value) {
    (IntType(lo, hi) | HexType(lo, hi), Integer(n)) => n >= lo && n <= hi
    (FloatType(lo, hi), Real(n)) => finite(n) && n >= lo && n <= hi
    (FloatType(lo, hi), Integer(n)) =>
      n.to_double() >= lo && n.to_double() <= hi
    (StringType, Text(_)) => true
    (EnumType(choices), Integer(n)) =>
      n >= 0L && n < choices.length().to_int64()
    _ => false
  }
}

///|
/// Resolve an explicit assignment or fall back to the attribute's default.
pub fn Database::attribute_value(
  self : Database,
  name : String,
  target : ObjectRef,
) -> AttributeValue? {
  for a in self.attributes {
    if a.name == name && a.target == Some(target) {
      return Some(a.value)
    }
  }
  for d in self.attribute_definitions {
    if d.name == name && d.scope == object_scope(target) {
      for a in self.attributes {
        if a.name == name && a.target is None {
          return Some(a.value)
        }
      }
    }
  }
  None
}

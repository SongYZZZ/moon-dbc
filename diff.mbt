///|
/// Kind of semantic revision; no source line comparison is involved.
pub(all) enum ChangeKind {
  Added
  Removed
  Changed
} derive(Eq, @debug.Debug)

///|
/// One changed semantic field; breaking marks frame interpretation changes.
pub(all) struct Change {
  kind : ChangeKind
  message_id : UInt?
  message_name : String?
  signal_name : String?
  field : String
  before : String
  after : String
  breaking : Bool
} derive(Eq, @debug.Debug)

///|
fn add_change(
  out : Array[Change],
  field : String,
  before : String,
  after : String,
  message? : Message? = None,
  signal? : Signal? = None,
  breaking? : Bool = false,
  kind? : ChangeKind = Changed,
) -> Unit {
  if before == after {
    return
  }
  out.push({
    kind,
    message_id: message.map(fn(m) { m.raw_dbc_id }),
    message_name: message.map(fn(m) { m.name }),
    signal_name: signal.map(fn(s) { s.name }),
    field,
    before,
    after,
    breaking,
  })
}

///|
fn values_signature(s : Signal) -> String {
  let values = s.values.map(fn(v) { "\{v.raw}=\{quote_dbc(v.label)}" })
  values.sort()
  values.join(";")
}

///|
fn receivers_signature(s : Signal) -> String {
  let names = s.receivers.copy()
  names.sort()
  names.join(",")
}

///|
fn signal_diff(
  old : Signal,
  new : Signal,
  m : Message,
  out : Array[Change],
) -> Unit {
  let message = Some(m)
  let signal = Some(new)
  add_change(
    out,
    "start_bit",
    old.start_bit.to_string(),
    new.start_bit.to_string(),
    message~,
    signal~,
    breaking=true,
  )
  add_change(
    out,
    "bit_length",
    old.bit_length.to_string(),
    new.bit_length.to_string(),
    message~,
    signal~,
    breaking=true,
  )
  add_change(
    out,
    "byte_order",
    if old.byte_order == Intel {
      "Intel"
    } else {
      "Motorola"
    },
    if new.byte_order == Intel {
      "Intel"
    } else {
      "Motorola"
    },
    message~,
    signal~,
    breaking=true,
  )
  add_change(
    out,
    "signed",
    old.signed.to_string(),
    new.signed.to_string(),
    message~,
    signal~,
    breaking=true,
  )
  add_change(
    out,
    "factor",
    double_text(old.factor),
    double_text(new.factor),
    message~,
    signal~,
    breaking=true,
  )
  add_change(
    out,
    "offset",
    double_text(old.offset),
    double_text(new.offset),
    message~,
    signal~,
    breaking=true,
  )
  add_change(
    out,
    "minimum",
    double_text(old.minimum),
    double_text(new.minimum),
    message~,
    signal~,
  )
  add_change(
    out,
    "maximum",
    double_text(old.maximum),
    double_text(new.maximum),
    message~,
    signal~,
  )
  add_change(out, "unit", old.unit, new.unit, message~, signal~)
  add_change(
    out,
    "receivers",
    receivers_signature(old),
    receivers_signature(new),
    message~,
    signal~,
  )
  add_change(
    out,
    "values",
    values_signature(old),
    values_signature(new),
    message~,
    signal~,
  )
  let mux_text = fn(s : Signal) {
    match s.multiplex {
      Always => "always"
      Multiplexer => "M"
      Branch(n) => "m\{n}"
    }
  }
  add_change(
    out,
    "multiplex",
    mux_text(old),
    mux_text(new),
    message~,
    signal~,
    breaking=true,
  )
}

///|
fn metadata_signature(db : Database) -> String {
  let parts = []
  for c in db.comments {
    parts.push("CM_ " + object_text(c.target) + quote_dbc(c.text))
  }
  for d in db.attribute_definitions {
    parts.push(
      "BA_DEF_ " +
      scope_text(d.scope) +
      quote_dbc(d.name) +
      attribute_type_text(d.kind),
    )
  }
  for a in db.attributes {
    parts.push(
      "BA_ " +
      quote_dbc(a.name) +
      (match a.target {
        Some(t) => object_text(t)
        None => "default "
      }) +
      attribute_value_text(a.value),
    )
  }
  for u in db.unsupported {
    parts.push(u.text)
  }
  parts.sort()
  parts.join("\n")
}

///|
/// Compare message identity, signal semantics and global metadata, ignoring source spans.
pub fn diff_database(old : Database, new : Database) -> Array[Change] {
  let out = []
  add_change(out, "version", old.version, new.version)
  let old_nodes = old.nodes.map(fn(n) { n.name })
  let new_nodes = new.nodes.map(fn(n) { n.name })
  old_nodes.sort()
  new_nodes.sort()
  add_change(out, "nodes", old_nodes.join(","), new_nodes.join(","))
  add_change(out, "metadata", metadata_signature(old), metadata_signature(new))
  for m in old.messages {
    match new.message_by_id(m.frame_id) {
      None =>
        add_change(
          out,
          "message",
          m.name,
          "",
          message=Some(m),
          kind=Removed,
          breaking=true,
        )
      Some(n) => {
        add_change(out, "name", m.name, n.name, message=Some(n), breaking=true)
        add_change(
          out,
          "length",
          m.length.to_string(),
          n.length.to_string(),
          message=Some(n),
          breaking=true,
        )
        add_change(
          out,
          "transmitter",
          m.transmitter,
          n.transmitter,
          message=Some(n),
        )
        for s in m.signals {
          match n.signal_by_name(s.name) {
            None =>
              add_change(
                out,
                "signal",
                s.name,
                "",
                message=Some(n),
                signal=Some(s),
                kind=Removed,
                breaking=true,
              )
            Some(t) => signal_diff(s, t, n, out)
          }
        }
        for s in n.signals {
          if m.signal_by_name(s.name) is None {
            add_change(
              out,
              "signal",
              "",
              s.name,
              message=Some(n),
              signal=Some(s),
              kind=Added,
            )
          }
        }
      }
    }
  }
  for m in new.messages {
    if old.message_by_id(m.frame_id) is None {
      add_change(out, "message", "", m.name, message=Some(m), kind=Added)
    }
  }
  out
}

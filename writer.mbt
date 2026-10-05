///|
fn quote_dbc(text : String) -> String {
  let out = StringBuilder::new()
  out.write_string("\"")
  for c in text {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(c)
    }
  }
  out.write_string("\"")
  out.to_string()
}

///|
fn double_text(value : Double) -> String {
  let text = value.to_string()
  if text.contains(".") || text.contains("e") || text.contains("E") {
    text
  } else {
    text + ".0"
  }
}

///|
fn scope_text(scope : Scope) -> String {
  match scope {
    DatabaseScope => ""
    NodeScope => "BU_ "
    MessageScope => "BO_ "
    SignalScope => "SG_ "
  }
}

///|
fn object_text(target : ObjectRef) -> String {
  match target {
    DatabaseRef => ""
    NodeRef(n) => "BU_ \{n} "
    MessageRef(id) => "BO_ \{id} "
    SignalRef(id, n) => "SG_ \{id} \{n} "
  }
}

///|
fn attribute_type_text(kind : AttributeType) -> String {
  match kind {
    IntType(lo, hi) => "INT \{lo} \{hi}"
    HexType(lo, hi) => "HEX \{lo} \{hi}"
    FloatType(lo, hi) => "FLOAT \{double_text(lo)} \{double_text(hi)}"
    StringType => "STRING"
    EnumType(choices) => "ENUM " + choices.map(quote_dbc).join(",")
  }
}

///|
fn attribute_value_text(value : AttributeValue) -> String {
  match value {
    Integer(n) => n.to_string()
    Real(n) => double_text(n)
    Text(t) => quote_dbc(t)
  }
}

///|
/// Deterministic semantic serialization. Reject invalid models rather than losing data.
/// Permissively preserved extensions are written verbatim after structured content.
pub fn write_dbc(db : Database) -> String raise DbcError {
  for d in validate_database(db) {
    if d.severity == Error {
      raise Failure(d)
    }
  }
  let out = StringBuilder::new()
  out.write_string("VERSION \{quote_dbc(db.version)}\n\nNS_ :\n\nBS_:\n\nBU_:")
  for n in db.nodes {
    out.write_string(" \{n.name}")
  }
  out.write_string("\n\n")
  for m in db.messages {
    out.write_string(
      "BO_ \{m.raw_dbc_id} \{m.name}: \{m.length} \{m.transmitter}\n",
    )
    for s in m.signals {
      let mux = match s.multiplex {
        Always => ""
        Multiplexer => " M"
        Branch(n) => " m\{n}"
      }
      let order = if s.byte_order == Intel { 1 } else { 0 }
      let sign = if s.signed { "-" } else { "+" }
      out.write_string(
        " SG_ \{s.name}\{mux} : \{s.start_bit}|\{s.bit_length}@\{order}\{sign} (\{double_text(s.factor)},\{double_text(s.offset)}) [\{double_text(s.minimum)}|\{double_text(s.maximum)}] \{quote_dbc(s.unit)} \{s.receivers.join(",")}\n",
      )
    }
    out.write_string("\n")
  }
  for c in db.comments {
    out.write_string("CM_ \{object_text(c.target)}\{quote_dbc(c.text)};\n")
  }
  for m in db.messages {
    for s in m.signals {
      if s.values.length() == 0 {
        continue
      }
      out.write_string("VAL_ \{m.raw_dbc_id} \{s.name}")
      for v in s.values {
        out.write_string(" \{v.raw} \{quote_dbc(v.label)}")
      }
      out.write_string(";\n")
    }
  }
  for d in db.attribute_definitions {
    out.write_string(
      "BA_DEF_ \{scope_text(d.scope)}\{quote_dbc(d.name)} \{attribute_type_text(d.kind)};\n",
    )
  }
  for a in db.attributes {
    match a.target {
      None =>
        out.write_string(
          "BA_DEF_DEF_ \{quote_dbc(a.name)} \{attribute_value_text(a.value)};\n",
        )
      Some(target) =>
        out.write_string(
          "BA_ \{quote_dbc(a.name)} \{object_text(target)}\{attribute_value_text(a.value)};\n",
        )
    }
  }
  for u in db.unsupported {
    out.write_string(u.text + "\n")
  }
  out.to_string()
}

///|
/// Parse the supported DBC subset using strict syntax and default budgets.
pub fn parse_dbc(source : String) -> Database raise DbcError {
  parse_dbc_with_options(source, ParseOptions::default())
}

///|
/// Bounded parsing. Semantic diagnostics remain inspectable via validation.
pub fn parse_dbc_with_options(
  source : String,
  options : ParseOptions,
) -> Database raise DbcError {
  let p = Parser::{
    tokens: lex(source, options.limits),
    index: 0,
    limits: options.limits,
  }
  let db = Database::new()
  let pending : Array[(UInt, String, Array[ValueDescription], SourceLocation)] = []
  let mut current : Message? = None
  let mut total_signals = 0
  let mut metadata_records = 0
  while true {
    p.skip_lines()
    if p.peek().text == "" && !p.peek().quoted {
      break
    }
    let head = p.take()
    if head.quoted {
      p.error("parse.keyword", "quoted statement keyword")
    }
    match head.text {
      "VERSION" => {
        db.version = p.quoted()
        p.end_line()
      }
      "NS_" => {
        p.expect(":")
        while p.peek().text != "BS_" && p.peek().text != "" {
          let declaration = p.take()
          if declaration.text != "\n" &&
            (declaration.quoted || !valid_name(declaration.text)) {
            p.error(
              "parse.namespace", "invalid namespace declaration or missing BS_ terminator",
            )
          }
        }
        if p.peek().text == "" {
          p.error("parse.namespace", "NS_ must terminate at BS_")
        }
      }
      "BS_" => {
        p.expect(":")
        p.end_line()
      }
      "BU_" => {
        p.expect(":")
        while p.peek().text != "\n" && p.peek().text != "" {
          let location = p.peek().location
          if db.nodes.length() >= p.limits.max_nodes {
            p.error("limit.nodes", "node budget exceeded")
          }
          db.nodes.push({ name: p.name(), location })
        }
        p.end_line()
      }
      "BO_" => {
        let raw_dbc_id = p.id()
        let frame_id = frame_id_from_dbc(raw_dbc_id) catch {
          Failure(d) =>
            raise Failure(diagnostic(d.code, d.message, location=head.location))
        }
        let name = p.name()
        p.expect(":")
        let length = p.small_integer()
        let transmitter = p.name()
        p.end_line()
        if length > 64 {
          p.error("message.length", "payload must be 0..64 bytes")
        }
        if db.messages.length() >= p.limits.max_messages {
          p.error("limit.messages", "message budget exceeded")
        }
        let message = Message::{
          raw_dbc_id,
          frame_id,
          name,
          length,
          transmitter,
          signals: [],
          location: head.location,
        }
        db.messages.push(message)
        current = Some(message)
      }
      "SG_" => {
        let message = match current {
          Some(m) => m
          None => {
            p.error("parse.orphan_signal", "SG_ must follow BO_")
            continue
          }
        }
        let signal = parse_signal(p, head.location)
        try signal_bits(signal, message.length) catch {
          Failure(d) =>
            raise Failure(signal_diagnostic(message, signal, d.code, d.message))
        } noraise {
          _ => ()
        }
        if signal.factor == 0.0 {
          raise Failure(
            signal_diagnostic(
              message, signal, "signal.factor", "zero scaling factor",
            ),
          )
        }
        if signal.minimum > signal.maximum {
          raise Failure(
            signal_diagnostic(
              message, signal, "signal.range", "minimum exceeds maximum",
            ),
          )
        }
        if message.signals.length() >= p.limits.max_signals_per_message ||
          total_signals >= p.limits.max_total_signals {
          p.error("limit.signals", "signal budget exceeded")
        }
        message.signals.push(signal)
        total_signals += 1
      }
      "CM_" => {
        let target = p.object_ref()
        let text = p.quoted()
        p.expect(";")
        db.comments.push({ target, text, location: head.location })
      }
      "VAL_" => {
        let id = p.id()
        let name = p.name()
        let values = []
        while p.peek().text != ";" {
          p.skip_lines()
          if p.peek().text == ";" {
            break
          }
          let raw = p.integer()
          let label = p.quoted()
          metadata_records += 1
          if metadata_records > p.limits.max_metadata_records {
            p.error("limit.metadata", "metadata budget exceeded")
          }
          values.push({ raw, label })
        }
        p.expect(";")
        pending.push((id, name, values, head.location))
      }
      "BA_DEF_" =>
        db.attribute_definitions.push(
          parse_attribute_definition(p, head.location),
        )
      "BA_DEF_DEF_" => {
        let name = p.quoted()
        let value = parse_attribute_value(p)
        p.expect(";")
        db.attributes.push({
          name,
          target: None,
          value,
          location: head.location,
        })
      }
      "BA_" => {
        let name = p.quoted()
        let target = p.object_ref()
        let value = parse_attribute_value(p)
        p.expect(";")
        db.attributes.push({
          name,
          target: Some(target),
          value,
          location: head.location,
        })
      }
      _ => preserve_statement(p, source, head, options.mode, db)
    }
    if head.text != "BO_" &&
      head.text != "SG_" &&
      head.text != "BU_" &&
      head.text != "VERSION" &&
      head.text != "BS_" &&
      head.text != "NS_" {
      metadata_records += 1
      if metadata_records > p.limits.max_metadata_records {
        p.error("limit.metadata", "metadata budget exceeded")
      }
    }
    if head.text.has_prefix("BA_") &&
      p.tokens[p.index - 1].end_offset - head.location.offset >
      p.limits.max_attribute_size {
      p.error("limit.attribute", "attribute exceeds budget")
    }
  }
  for entry in pending {
    let (id, name, values, location) = entry
    let message = db.message_by_id(frame_id_from_dbc(id))
    match message {
      Some(m) =>
        match m.signal_by_name(name) {
          Some(s) =>
            for value in values {
              s.values.push(value)
            }
          None =>
            raise Failure(
              diagnostic(
                "values.signal",
                "VAL_ references unknown signal \{name}",
                location~,
              ),
            )
        }
      None =>
        raise Failure(
          diagnostic(
            "values.message",
            "VAL_ references unknown message \{id}",
            location~,
          ),
        )
    }
  }
  db
}

///|
fn parse_signal(p : Parser, location : SourceLocation) -> Signal raise DbcError {
  let name = p.name()
  let multiplex = if p.peek().text == ":" {
    Always
  } else {
    let mux = p.name()
    if mux == "M" {
      Multiplexer
    } else if mux.has_prefix("m") {
      let value = @string.parse_int64(mux[1:]) catch {
        _ => {
          p.error("mux.syntax", "expected m followed by a nonnegative integer")
          0L
        }
      }
      if value < 0L {
        p.error("mux.syntax", "negative branch")
      }
      Branch(value)
    } else {
      p.error("mux.syntax", "unsupported multiplex marker")
      Always
    }
  }
  p.expect(":")
  let start_bit = p.small_integer()
  p.expect("|")
  let bit_length = p.small_integer()
  if bit_length < 1 || bit_length > 64 {
    p.error("signal.length", "integer signals must be 1..64 bits")
  }
  p.expect("@")
  if p.peek().quoted {
    p.error("signal.order", "quoted byte order is invalid")
  }
  let byte_order = match p.take().text {
    "1" => Intel
    "0" => Motorola
    _ => {
      p.error("signal.order", "byte order must be 0 or 1")
      Intel
    }
  }
  if p.peek().quoted {
    p.error("signal.sign", "quoted signedness is invalid")
  }
  let signed = match p.take().text {
    "+" => false
    "-" => true
    _ => {
      p.error("signal.sign", "signedness must be + or -")
      false
    }
  }
  p.expect("(")
  let factor = p.real()
  p.expect(",")
  let offset = p.real()
  p.expect(")")
  p.expect("[")
  let minimum = p.real()
  p.expect("|")
  let maximum = p.real()
  p.expect("]")
  let unit = p.quoted()
  let receivers = []
  while p.peek().text != "\n" && p.peek().text != "" {
    receivers.push(p.name())
    if p.peek().text == "," {
      p.index += 1
      if p.peek().text == "\n" || p.peek().text == "" {
        p.error("parse.receiver", "missing receiver after comma")
      }
    } else {
      break
    }
  }
  p.end_line()
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
    location,
  }
}

///|
fn parse_attribute_definition(
  p : Parser,
  location : SourceLocation,
) -> AttributeDefinition raise DbcError {
  let scope = if p.peek().quoted {
    DatabaseScope
  } else {
    match p.peek().text {
      "BU_" => {
        p.index += 1
        NodeScope
      }
      "BO_" => {
        p.index += 1
        MessageScope
      }
      "SG_" => {
        p.index += 1
        SignalScope
      }
      _ => DatabaseScope
    }
  }
  let name = p.quoted()
  let type_token = p.take()
  if type_token.quoted {
    raise Failure(
      diagnostic(
        "attribute.type",
        "quoted attribute type",
        location=type_token.location,
      ),
    )
  }
  let kind = match type_token.text {
    "INT" => IntType(p.integer(), p.integer())
    "HEX" => HexType(p.integer(), p.integer())
    "FLOAT" => FloatType(p.real(), p.real())
    "STRING" => StringType
    "ENUM" => {
      let choices = [p.quoted()]
      while p.peek().text == "," {
        p.expect(",")
        choices.push(p.quoted())
      }
      EnumType(choices)
    }
    _ => {
      p.error("attribute.type", "unsupported attribute definition type")
      StringType
    }
  }
  p.expect(";")
  if p.peek().location.offset - location.offset > p.limits.max_attribute_size {
    p.error("limit.attribute", "attribute exceeds budget")
  }
  { name, scope, kind, location }
}

///|
fn parse_attribute_value(p : Parser) -> AttributeValue raise DbcError {
  if p.peek().quoted {
    return Text(p.quoted())
  }
  let location = p.peek().location
  let text = p.number_text()
  if !text.has_prefix("0x") &&
    !text.has_prefix("0X") &&
    (text.contains(".") || text.contains("e") || text.contains("E")) {
    let value = @string.parse_double(text) catch {
      _ =>
        raise Failure(
          diagnostic("attribute.value", "invalid numeric attribute", location~),
        )
    }
    if !finite(value) {
      p.error("attribute.value", "nonfinite attribute")
    }
    Real(value)
  } else {
    Integer(
      @string.parse_int64(text) catch {
        _ =>
          raise Failure(
            diagnostic(
              "attribute.value",
              "invalid integer attribute",
              location~,
            ),
          )
      },
    )
  }
}

///|
fn preserve_statement(
  p : Parser,
  source : String,
  head : Token,
  mode : ParseMode,
  db : Database,
) -> Unit raise DbcError {
  if head.text == "SG_MUL_VAL_" ||
    head.text == "SIG_VALTYPE_" ||
    head.text == "SIG_TYPE_REF_" {
    raise Failure(
      diagnostic(
        "parse.critical_extension",
        "unsupported codec-critical statement \{head.text}",
        location=head.location,
      ),
    )
  }
  if mode == Strict {
    raise Failure(
      diagnostic(
        "parse.unsupported",
        "unsupported statement \{head.text}",
        location=head.location,
      ),
    )
  }
  let mut end_offset = head.end_offset
  while (p.peek().text != "\n" || p.peek().quoted) &&
        (p.peek().text != "" || p.peek().quoted) {
    let t = p.take()
    end_offset = t.end_offset
    if t.text == ";" && !t.quoted {
      break
    }
  }
  db.unsupported.push({
    keyword: head.text,
    text: source[head.location.offset:end_offset].to_owned(),
    location: head.location,
  })
  db.diagnostics.push(
    diagnostic(
      "parse.preserved",
      "preserved unsupported statement \{head.text}",
      location=head.location,
      severity=Warning,
    ),
  )
}

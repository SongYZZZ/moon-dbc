///|
priv struct Parser {
  tokens : Array[Token]
  mut index : Int
  limits : ParseLimits
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.index]
}

///|
fn Parser::error(
  self : Parser,
  code : String,
  message : String,
) -> Unit raise DbcError {
  raise Failure(diagnostic(code, message, location=self.peek().location))
}

///|
fn Parser::take(self : Parser) -> Token raise DbcError {
  let t = self.peek()
  if t.text == "" && !t.quoted {
    self.error("parse.eof", "unexpected end of input")
  }
  self.index += 1
  t
}

///|
fn Parser::skip_lines(self : Parser) -> Unit {
  while self.peek().text == "\n" {
    self.index += 1
  }
}

///|
fn Parser::expect(self : Parser, text : String) -> Unit raise DbcError {
  let t = self.take()
  if t.quoted || t.text != text {
    raise Failure(
      diagnostic(
        "parse.expected",
        "expected \{text}, got \{t.text}",
        location=t.location,
      ),
    )
  }
}

///|
fn Parser::quoted(self : Parser) -> String raise DbcError {
  let t = self.take()
  if !t.quoted {
    raise Failure(
      diagnostic(
        "parse.string",
        "expected a quoted string",
        location=t.location,
      ),
    )
  }
  t.text
}

///|
fn valid_name(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  for i = 0; i < name.length(); i = i + 1 {
    let c = name[i].to_int()
    let letter = (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
    if !letter && !(i > 0 && c >= 48 && c <= 57) {
      return false
    }
  }
  true
}

///|
fn Parser::name(self : Parser) -> String raise DbcError {
  let t = self.take()
  if t.quoted || !valid_name(t.text) {
    raise Failure(
      diagnostic("parse.name", "invalid identifier", location=t.location),
    )
  }
  if t.text.length() > self.limits.max_name_length {
    raise Failure(
      diagnostic("limit.name", "identifier exceeds budget", location=t.location),
    )
  }
  t.text
}

///|
fn Parser::number_text(self : Parser) -> String raise DbcError {
  let mut prefix = ""
  if self.peek().text == "-" || self.peek().text == "+" {
    prefix = self.take().text
  }
  let t = self.take()
  if t.quoted {
    self.error("parse.number", "quoted numeric literal")
  }
  prefix + t.text
}

///|
fn Parser::integer(self : Parser) -> Int64 raise DbcError {
  let location = self.peek().location
  let text = self.number_text()
  @string.parse_int64(text) catch {
    _ =>
      raise Failure(
        diagnostic(
          "parse.integer",
          "invalid or overflowing integer: \{text}",
          location~,
        ),
      )
  }
}

///|
fn Parser::small_integer(self : Parser) -> Int raise DbcError {
  let n = self.integer()
  if n < 0L || n > 2147483647L {
    self.error("parse.integer", "expected nonnegative 32-bit integer")
  }
  n.to_int()
}

///|
fn Parser::id(self : Parser) -> UInt raise DbcError {
  let n = self.integer()
  if n < 0L || n > 4294967295L {
    self.error("parse.id", "DBC ID must be a 32-bit unsigned integer")
  }
  n.to_int().reinterpret_as_uint()
}

///|
fn finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn Parser::real(self : Parser) -> Double raise DbcError {
  let location = self.peek().location
  let text = self.number_text()
  let value = @string.parse_double(text) catch {
    _ =>
      raise Failure(
        diagnostic(
          "parse.number",
          "invalid floating point literal: \{text}",
          location~,
        ),
      )
  }
  if !finite(value) {
    raise Failure(
      diagnostic("parse.number", "nonfinite numeric literal", location~),
    )
  }
  value
}

///|
fn Parser::end_line(self : Parser) -> Unit raise DbcError {
  let t = self.peek()
  if t.text == "\n" {
    self.index += 1
  } else if t.text != "" || t.quoted {
    self.error("parse.trailing", "unexpected tokens at end of line")
  }
}

///|
fn Parser::object_ref(self : Parser) -> ObjectRef raise DbcError {
  match self.peek().text {
    "BU_" => {
      self.index += 1
      NodeRef(self.name())
    }
    "BO_" => {
      self.index += 1
      MessageRef(self.id())
    }
    "SG_" => {
      self.index += 1
      SignalRef(self.id(), self.name())
    }
    _ => DatabaseRef
  }
}

///|
fn object_scope(target : ObjectRef) -> Scope {
  match target {
    DatabaseRef => DatabaseScope
    NodeRef(_) => NodeScope
    MessageRef(_) => MessageScope
    SignalRef(_, _) => SignalScope
  }
}

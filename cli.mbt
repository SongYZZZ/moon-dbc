///|
/// File CLI commands; parsing is pure and the process boundary owns filesystem IO.
pub(all) enum CommandKind {
  Help
  VersionCommand
  Inspect
  Validate
  Decode
  Encode
  Diff
  Layout
  Normalize
} derive(Eq, @debug.Debug)

///|
/// Checked CLI arguments, including explicit raw/physical mode.
pub(all) struct Command {
  kind : CommandKind
  path : String
  second_path : String?
  message_id : UInt?
  hex : String
  assignments : Array[String]
  raw : Bool
  permissive : Bool
  json : Bool
} derive(Eq, @debug.Debug)

///|
/// Text output and conventional status: 0 success, 1 validation/diff, 2 usage/error.
pub(all) struct CliOutput {
  text : String
  exit_code : Int
} derive(Eq, @debug.Debug)

///|
/// Parse user arguments without reading files. IDs use decimal or 0x notation.
pub fn parse_cli_arguments(args : Array[String]) -> Command raise DbcError {
  let mut raw = false
  let mut permissive = false
  let mut json = false
  let positional = []
  let mut message = None
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "--raw" => raw = true
      "--permissive" => permissive = true
      "--json" => json = true
      "--message" => {
        i += 1
        if i >= args.length() {
          fail("cli.arguments", "--message requires an ID")
        }
        message = Some(parse_cli_id(args[i]))
      }
      a => {
        if a.has_prefix("--") && a != "--help" && a != "--version" {
          fail("cli.arguments", "unknown flag \{a}")
        }
        positional.push(a)
      }
    }
    i += 1
  }
  let first = if positional.length() == 0 { "help" } else { positional[0] }
  let kind = match first {
    "help" | "--help" => Help
    "version" | "--version" => VersionCommand
    "inspect" => Inspect
    "validate" => Validate
    "decode" => Decode
    "encode" => Encode
    "diff" => Diff
    "layout" => Layout
    "normalize" => Normalize
    _ => {
      fail("cli.arguments", "unknown command \{first}")
      Help
    }
  }
  let min_args = match kind {
    Help | VersionCommand => 1
    Inspect | Validate | Normalize => 2
    Diff | Layout | Encode => 3
    Decode => 4
  }
  if kind != Help && positional.length() < min_args {
    fail("cli.arguments", "missing command arguments")
  }
  if kind != Encode && positional.length() > min_args {
    fail("cli.arguments", "unexpected positional argument")
  }
  if raw && kind != Encode {
    fail("cli.arguments", "--raw is only valid for encode")
  }
  if json && kind != Decode {
    fail("cli.arguments", "--json is currently supported by decode")
  }
  if message is Some(_) && kind != Inspect {
    fail("cli.arguments", "--message is only valid for inspect")
  }
  let path = if min_args >= 2 { positional[1] } else { "" }
  let message_id = match kind {
    Decode | Encode | Layout => Some(parse_cli_id(positional[2]))
    _ => message
  }
  let second_path = if kind == Diff { Some(positional[2]) } else { None }
  let hex = if kind == Decode { positional[3] } else { "" }
  let assignments = if kind == Encode { positional[3:].to_owned() } else { [] }
  {
    kind,
    path,
    second_path,
    message_id,
    hex,
    assignments,
    raw,
    permissive,
    json,
  }
}

///|
fn parse_cli_id(text : String) -> UInt raise DbcError {
  @string.parse_uint(text) catch {
    _ => {
      fail("cli.id", "invalid 32-bit ID: \{text}")
      0U
    }
  }
}

///|
/// Parse hexadecimal payload bytes, rejecting odd lengths and invalid characters.
pub fn parse_frame_hex(text : String) -> Array[Byte] raise DbcError {
  if text.length() % 2 != 0 || text.length() > 128 {
    fail("cli.hex", "payload must contain 0..64 complete hexadecimal bytes")
  }
  let bytes = []
  for i = 0; i < text.length(); i = i + 2 {
    let hi = hex_nibble(text[i].to_int())
    let lo = hex_nibble(text[i + 1].to_int())
    if hi < 0 || lo < 0 {
      fail("cli.hex", "invalid hexadecimal digit")
    }
    bytes.push((hi * 16 + lo).to_byte())
  }
  bytes
}

///|
fn hex_nibble(c : Int) -> Int {
  if c >= 48 && c <= 57 {
    c - 48
  } else if c >= 65 && c <= 70 {
    c - 55
  } else if c >= 97 && c <= 102 {
    c - 87
  } else {
    -1
  }
}

///|
/// Render payload bytes as uppercase hex without separators.
pub fn frame_hex(payload : Array[Byte]) -> String {
  let alphabet = "0123456789ABCDEF"
  let out = StringBuilder::new()
  for b in payload {
    let n = b.to_int()
    out.write_stringview(alphabet[n / 16:n / 16 + 1])
    out.write_stringview(alphabet[n % 16:n % 16 + 1])
  }
  out.to_string()
}

///|
/// Render stable diagnostic context for terminals/logs.
pub fn render_diagnostic(d : Diagnostic) -> String {
  let severity = if d.severity == Error { "error" } else { "warning" }
  let object = d.message_name.unwrap_or("") +
    (match d.signal_name {
      Some(s) => "." + s
      None => ""
    })
  "\{severity} [\{d.code}] line \{d.location.line}:\{d.location.column} \{object}: \{d.message}"
}

///|
/// Usage text shared by executable and CLI tests.
pub fn cli_help() -> String {
  "moon-dbc 0.1.0\nUsage:\n  moon-dbc inspect FILE [--message DBC_ID]\n  moon-dbc validate FILE\n  moon-dbc decode FILE DBC_ID HEX [--json]\n  moon-dbc encode FILE DBC_ID [--raw] Signal=value ...\n  moon-dbc layout FILE DBC_ID\n  moon-dbc diff OLD NEW\n  moon-dbc normalize FILE\nAll file commands accept --permissive. IDs: decimal or 0x, extended DBC IDs include bit 31.\nPhysical inputs are numbers; enum inputs use label:Name. Raw inputs are exact integers.\n"
}

///|
fn cli_message(db : Database, id : UInt?) -> Message raise DbcError {
  let raw_id = match id {
    Some(v) => v
    None => {
      fail("cli.id", "message ID required")
      0U
    }
  }
  match db.message_by_id(frame_id_from_dbc(raw_id)) {
    Some(m) => m
    None => {
      fail("codec.unknown_id", "unknown DBC message ID \{raw_id}")
      Message::new({ id: 0U, extended: false }, "", 0)
    }
  }
}

///|
fn parse_assignment(
  message : Message,
  text : String,
  raw : Bool,
) -> SignalAssignment raise DbcError {
  let split = match text.find("=") {
    Some(i) => i
    None => {
      fail("cli.assignment", "expected Signal=value")
      0
    }
  }
  let name = text[:split].to_owned()
  let literal = text[split + 1:].to_owned()
  let s = match message.signal_by_name(name) {
    Some(v) => v
    None => {
      fail("codec.unknown_signal", "unknown signal \{name}")
      Signal::new("", 0, 1)
    }
  }
  let value = if raw {
    if literal.has_prefix("label:") {
      fail("cli.assignment", "labels are physical-mode inputs")
    }
    if s.signed {
      Raw(
        Signed(
          @string.parse_int64(literal) catch {
            _ => {
              fail("cli.assignment", "invalid signed raw integer")
              0L
            }
          },
        ),
      )
    } else {
      Raw(
        Unsigned(
          @string.parse_uint64(literal) catch {
            _ => {
              fail("cli.assignment", "invalid unsigned raw integer")
              0UL
            }
          },
        ),
      )
    }
  } else if literal.has_prefix("label:") {
    Label(literal[6:].to_owned())
  } else {
    let n = @string.parse_double(literal) catch {
      _ => {
        fail("cli.assignment", "invalid physical number")
        0.0
      }
    }
    if !finite(n) {
      fail("cli.assignment", "physical number must be finite")
    }
    Physical(n)
  }
  { name, value }
}

///|
fn raw_text(raw : RawValue) -> String {
  match raw {
    Signed(v) => v.to_string()
    Unsigned(v) => v.to_string()
  }
}

///|
fn decoded_text(decoded : DecodedMessage) -> String {
  let lines = ["Message: \{decoded.name} (DBC ID \{decoded.frame_id.to_dbc()})"]
  for s in decoded.signals {
    lines.push(
      "\{s.name}: raw=\{raw_text(s.raw)} value=\{s.physical} \{s.unit}" +
      (match s.label {
        Some(v) => " (" + v + ")"
        None => ""
      }),
    )
  }
  for d in decoded.diagnostics {
    lines.push(render_diagnostic(d))
  }
  lines.join("\n")
}

///|
fn decoded_json(decoded : DecodedMessage) -> String {
  // Raw integers are strings to preserve 64-bit precision in JavaScript consumers.
  let rows = decoded.signals.map(fn(s) {
    "{\"name\":\{quote_dbc(s.name)},\"raw\":\{quote_dbc(raw_text(s.raw))},\"physical\":\{s.physical},\"unit\":\{quote_dbc(s.unit)},\"label\":" +
    (match s.label {
      Some(v) => quote_dbc(v)
      None => "null"
    }) +
    ",\"out_of_range\":\{s.out_of_range}}"
  })
  let diagnostics = decoded.diagnostics.map(fn(d) {
    "{\"code\":\{quote_dbc(d.code)},\"message\":\{quote_dbc(d.message)}}"
  })
  "{\"message\":\{quote_dbc(decoded.name)},\"dbc_id\":\{decoded.frame_id.to_dbc()},\"signals\":[" +
  rows.join(",") +
  "],\"diagnostics\":[" +
  diagnostics.join(",") +
  "]}"
}

///|
/// Execute a parsed CLI command on caller-supplied file contents; no IO in core.
pub fn execute_cli(
  command : Command,
  source : String,
  second_source? : String = "",
) -> CliOutput raise DbcError {
  if command.kind == Help {
    return { text: cli_help(), exit_code: 0 }
  }
  if command.kind == VersionCommand {
    return { text: "moon-dbc 0.1.0", exit_code: 0 }
  }
  let options = ParseOptions::{
    mode: if command.permissive {
      Permissive
    } else {
      Strict
    },
    limits: ParseLimits::default(),
  }
  let db = parse_dbc_with_options(source, options)
  let findings = validate_database(db)
  let errors = findings.filter(fn(d) { d.severity == Error }).length()
  if command.kind == Validate {
    let lines = findings.map(render_diagnostic)
    lines.push(
      "Validation: \{errors} errors, \{findings.length()-errors} warnings",
    )
    return {
      text: lines.join("\n"),
      exit_code: if errors == 0 {
        0
      } else {
        1
      },
    }
  }
  if command.kind != Inspect && errors > 0 {
    raise Failure(
      findings.iter().find_first(fn(d) { d.severity == Error }).unwrap(),
    )
  }
  let text = match command.kind {
    Inspect => {
      let s = inspect_database(db)
      let summary = "DBC database\nVersion: \{db.version}\nNodes: \{s.nodes}\nMessages: \{s.messages}\nSignals: \{s.signals}\nStandard CAN messages: \{s.standard_messages}\nExtended CAN messages: \{s.extended_messages}\nClassic-sized messages: \{s.classic_sized_messages}\nCAN FD-sized messages: \{s.fd_sized_messages}\nMultiplexed messages: \{s.multiplexed_messages}\nValue descriptions: \{s.value_descriptions}\nDiagnostics: \{s.errors} errors, \{s.warnings} warnings"
      if command.message_id is Some(_) {
        summary + "\n" + render_layout(cli_message(db, command.message_id))
      } else {
        summary
      }
    }
    Decode => {
      let m = cli_message(db, command.message_id)
      let decoded = decode_frame(db, {
        frame_id: m.frame_id,
        payload: parse_frame_hex(command.hex),
      })
      if command.json {
        decoded_json(decoded)
      } else {
        decoded_text(decoded)
      }
    }
    Encode => {
      let m = cli_message(db, command.message_id)
      let assignments = command.assignments.map(fn(text) raise DbcError {
        parse_assignment(m, text, command.raw)
      })
      let result = encode_message(m, assignments)
      let warnings = result.diagnostics.map(render_diagnostic)
      frame_hex(result.frame.payload) +
      (if warnings.length() > 0 { "\n" + warnings.join("\n") } else { "" })
    }
    Layout => render_layout(cli_message(db, command.message_id))
    Normalize => write_dbc(db)
    Diff => {
      let other = parse_dbc_with_options(second_source, options)
      for d in validate_database(other) {
        if d.severity == Error {
          raise Failure(d)
        }
      }
      let changes = diff_database(db, other)
      let rows = changes.map(fn(c) {
        let context = c.message_name.unwrap_or("database") +
          (match c.signal_name {
            Some(n) => "." + n
            None => ""
          })
        "\{context}.\{c.field}: \{c.before} -> \{c.after}"
      })
      return {
        text: "Semantic changes: \{changes.length()}" +
        (if rows.length() > 0 { "\n" + rows.join("\n") } else { "" }),
        exit_code: if changes.length() == 0 {
          0
        } else {
          1
        },
      }
    }
    Help | VersionCommand | Validate => ""
  }
  { text, exit_code: if errors == 0 { 0 } else { 1 } }
}

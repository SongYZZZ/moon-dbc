///|
test "empty database" {
  assert_eq(parse_dbc("").messages.length(), 0)
}

///|
test "whitespace only" {
  assert_eq(parse_dbc(" \t\r\n\n").nodes.length(), 0)
}

///|
test "version with spaces" {
  assert_eq(parse_dbc("VERSION \"hello world\"\n").version, "hello world")
}

///|
test "namespace declarations" {
  assert_eq(parse_dbc(basic_text()).version, "1.0")
}

///|
test "message structure" {
  let m = parse_dbc(basic_text()).messages[0]
  assert_eq(m.raw_dbc_id, 291U)
  assert_eq(m.name, "EngineData")
  assert_eq(m.length, 8)
  assert_eq(m.transmitter, "ECU")
}

///|
test "signal structure" {
  let s = parse_dbc(basic_text()).messages[0].signals[0]
  assert_eq(s.start_bit, 0)
  assert_eq(s.bit_length, 16)
  assert_eq(s.factor, 0.125)
  assert_eq(s.unit, "rpm")
  assert_eq(s.receivers, ["Dash"])
  assert_eq(s.location.line, 8)
}

///|
test "value metadata attachment" {
  assert_eq(
    parse_dbc(basic_text()).messages[0].signals[1].values[1].label,
    "Drive",
  )
}

///|
test "CRLF input" {
  assert_eq(
    parse_dbc(basic_text().replace_all(old="\n", new="\r\n")).messages.length(),
    1,
  )
}

///|
test "UTF8 comment and escape" {
  let db = parse_dbc("CM_ \"中文 with \\\"quotes\\\" and \\n newline\";\n")
  assert_eq(db.comments[0].text, "中文 with \"quotes\" and \n newline")
}

///|
test "multiline quoted comment" {
  assert_eq(parse_dbc("CM_ \"a\nb\";\n").comments[0].text, "a\nb")
}

///|
test "empty quoted text" {
  assert_eq(parse_dbc("VERSION \"\"\nCM_ \"\";\n").comments[0].text, "")
}

///|
test "unterminated quote" {
  expect_error(fn() raise DbcError { parse_dbc("CM_ \"abc") }, "lex.string")
}

///|
test "invalid escape" {
  expect_error(fn() raise DbcError { parse_dbc("CM_ \"\\z\";") }, "lex.escape")
}

///|
test "truncated message" {
  expect_error(fn() raise DbcError { parse_dbc("BO_ 1") }, "parse.eof")
}

///|
test "orphan signal" {
  expect_error(
    fn() raise DbcError { parse_dbc("SG_ A : 0|8@1+ (1,0) [0|1] \"\" X") },
    "parse.orphan_signal",
  )
}

///|
test "integer overflow" {
  expect_error(
    fn() raise DbcError { parse_dbc("BO_ 999999999999999999999999 A: 1 X") },
    "parse.integer",
  )
}

///|
test "missing terminator" {
  expect_error(fn() raise DbcError { parse_dbc("CM_ \"a\"") }, "parse.eof")
}

///|
test "strict unsupported keyword" {
  expect_error(fn() raise DbcError { parse_dbc("EV_ x;") }, "parse.unsupported")
}

///|
test "permissive preserves extension" {
  let db = parse_dbc_with_options("EV_ x;\n", {
    mode: Permissive,
    limits: ParseLimits::default(),
  })
  assert_eq(db.unsupported[0].text, "EV_ x;")
  assert_eq(db.diagnostics[0].severity, Warning)
}

///|
test "critical extensions rejected permissively" {
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options("SG_MUL_VAL_ 1 a b 0-2;", {
        mode: Permissive,
        limits: ParseLimits::default(),
      })
    },
    "parse.critical_extension",
  )
}

///|
test "multiplex markers" {
  let db = parse_dbc(
    "BO_ 1 M: 2 Vector__XXX\n SG_ Mode M : 0|8@1+ (1,0) [0|2] \"\" Vector__XXX\n SG_ Data m2 : 8|8@1+ (1,0) [0|255] \"\" Vector__XXX\n",
  )
  assert_eq(db.messages[0].signals[0].multiplex, Multiplexer)
  assert_eq(db.messages[0].signals[1].multiplex, Branch(2L))
}

///|
test "scientific and negative scaling" {
  let s = parse_dbc(
      "BO_ 1 A: 1 X\n SG_ B : 7|8@0- (1e-2,-4.5) [-4.5|1e+2] \"V\" X\n",
    ).messages[0].signals[0]
  assert_eq(s.byte_order, Motorola)
  assert_eq(s.factor, 0.01)
  assert_eq(s.offset, -4.5)
}

///|
test "extended flag retained" {
  assert_true(
    parse_dbc("BO_ 2147483939 X: 0 Vector__XXX\n").messages[0].frame_id.extended,
  )
}

///|
test "VAL forward reference" {
  assert_eq(
    parse_dbc(
      "VAL_ 1 S 1 \"On\";\nBO_ 1 X: 1 Z\n SG_ S : 0|8@1+ (1,0) [0|255] \"\" Z\n",
    ).messages[0].signals[0].values.length(),
    1,
  )
}

///|
test "unknown VAL message" {
  expect_error(
    fn() raise DbcError { parse_dbc("VAL_ 1 S 0 \"Off\";") },
    "values.message",
  )
}

///|
test "attribute definitions and defaults" {
  let db = parse_dbc(
    "BA_DEF_ BO_ \"Cycle\" INT 0 1000;\nBA_DEF_DEF_ \"Cycle\" 10;\nBA_ \"Cycle\" BO_ 1 20;\n",
  )
  assert_eq(db.attribute_definitions[0].kind, IntType(0L, 1000L))
  assert_eq(db.attributes[0].target, None)
  assert_eq(db.attributes[1].value, Integer(20L))
}

///|
test "enum attribute" {
  assert_eq(
    parse_dbc("BA_DEF_ \"Mode\" ENUM \"A\",\"B\";").attribute_definitions[0].kind,
    EnumType(["A", "B"]),
  )
}

///|
test "invalid signal length" {
  expect_error(
    fn() raise DbcError {
      parse_dbc("BO_ 1 A: 1 X\n SG_ B : 0|0@1+ (1,0) [0|1] \"\" X")
    },
    "signal.length",
  )
}

///|
test "nonfinite scaling rejected" {
  expect_error(
    fn() raise DbcError {
      parse_dbc("BO_ 1 A: 1 X\n SG_ B : 0|8@1+ (1e999,0) [0|1] \"\" X")
    },
    "parse.number",
  )
}

///|
test "line budget" {
  let limits = ParseLimits::{ ..ParseLimits::default(), max_line_length: 5 }
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options("VERSION \"x\"", { mode: Strict, limits })
    },
    "limit.line",
  )
}

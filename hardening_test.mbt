///|
test "namespace cannot swallow messages" {
  expect_error(
    fn() raise DbcError { parse_dbc("NS_ :\nBO_ 1 A: 1 X\n") },
    "parse.namespace",
  )
}

///|
test "namespace requires terminator" {
  expect_error(
    fn() raise DbcError { parse_dbc("NS_ :\n CM_\n") },
    "parse.namespace",
  )
}

///|
test "hex attribute with lowercase e remains integer" {
  assert_eq(
    parse_dbc("BA_ \"Mask\" 0xdead;").attributes[0].value,
    Integer(57005L),
  )
}

///|
test "hex attribute uppercase E remains integer" {
  assert_eq(
    parse_dbc("BA_ \"Mask\" 0XDEAD;").attributes[0].value,
    Integer(57005L),
  )
}

///|
test "permissive does not accept out of bounds signal" {
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options(
        "BO_ 1 A: 1 X\n SG_ S : 7|2@1+ (1,0) [0|3] \"\" X",
        { mode: Permissive, limits: ParseLimits::default() },
      )
    },
    "signal.bounds",
  )
}

///|
test "permissive does not accept zero factor" {
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options(
        "BO_ 1 A: 1 X\n SG_ S : 0|8@1+ (0,0) [0|3] \"\" X",
        { mode: Permissive, limits: ParseLimits::default() },
      )
    },
    "signal.factor",
  )
}

///|
test "file budget" {
  let limits = ParseLimits::{ ..ParseLimits::default(), max_file_size: 3 }
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options("VERSION \"\"", { mode: Strict, limits })
    },
    "limit.file",
  )
}

///|
test "token budget" {
  let limits = ParseLimits::{ ..ParseLimits::default(), max_tokens: 2 }
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options("VERSION \"\"\n", { mode: Strict, limits })
    },
    "limit.tokens",
  )
}

///|
test "name budget" {
  let limits = ParseLimits::{ ..ParseLimits::default(), max_name_length: 2 }
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options("BU_: Long\n", { mode: Strict, limits })
    },
    "limit.name",
  )
}

///|
test "node budget" {
  let limits = ParseLimits::{ ..ParseLimits::default(), max_nodes: 1 }
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options("BU_: A B\n", { mode: Strict, limits })
    },
    "limit.nodes",
  )
}

///|
test "message budget" {
  let limits = ParseLimits::{ ..ParseLimits::default(), max_messages: 0 }
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options("BO_ 1 A: 0 X\n", { mode: Strict, limits })
    },
    "limit.messages",
  )
}

///|
test "signal per message budget" {
  let limits = ParseLimits::{
    ..ParseLimits::default(),
    max_signals_per_message: 0,
  }
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options(
        "BO_ 1 A: 1 X\n SG_ S : 0|8@1+ (1,0) [0|255] \"\" X\n",
        { mode: Strict, limits },
      )
    },
    "limit.signals",
  )
}

///|
test "metadata budget" {
  let limits = ParseLimits::{
    ..ParseLimits::default(),
    max_metadata_records: 0,
  }
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options("CM_ \"x\";", { mode: Strict, limits })
    },
    "limit.metadata",
  )
}

///|
test "attribute assignment size budget" {
  let limits = ParseLimits::{ ..ParseLimits::default(), max_attribute_size: 4 }
  expect_error(
    fn() raise DbcError {
      parse_dbc_with_options("BA_ \"A\" \"long\";", { mode: Strict, limits })
    },
    "limit.attribute",
  )
}

///|
test "enum label default compatible with DBC ecosystem" {
  let db = parse_dbc(
    "BA_DEF_ \"Mode\" ENUM \"Off\",\"On\"; BA_DEF_DEF_ \"Mode\" \"On\";",
  )
  assert_eq(validate_database(db), [])
  assert_eq(diff_database(db, parse_dbc(write_dbc(db))), [])
}

///|
test "mux selector Warn reported once" {
  let m = Message::new({ id: 1U, extended: false }, "A", 1, signals=[
    Signal::new("M", 0, 8, maximum=1, multiplex=Multiplexer),
  ])
  let out = encode_message(
    m,
    [{ name: "M", value: Physical(2) }],
    range_policy=Warn,
  )
  assert_eq(out.diagnostics.length(), 1)
}

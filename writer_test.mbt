///|
test "core semantic roundtrip" {
  let a = parse_dbc(basic_text())
  let b = parse_dbc(write_dbc(a))
  assert_eq(diff_database(a, b), [])
}

///|
test "writer deterministic repeat" {
  let a = parse_dbc(basic_text())
  assert_eq(write_dbc(a), write_dbc(a))
}

///|
test "writer converges after parse" {
  let text = write_dbc(parse_dbc(basic_text()))
  assert_eq(write_dbc(parse_dbc(text)), text)
}

///|
test "multiplex writer roundtrip" {
  let db = Database::new()
  db.messages.push(mux_message())
  assert_eq(diff_database(db, parse_dbc(write_dbc(db))), [])
}

///|
test "UTF8 escaped comments roundtrip" {
  let db = parse_dbc("CM_ \"中文 \\n \\t \\\"quote\\\" \\\\slash\";")
  assert_eq(diff_database(db, parse_dbc(write_dbc(db))), [])
}

///|
test "all attribute types roundtrip" {
  let db = parse_dbc(
    "BA_DEF_ \"I\" INT -5 5; BA_DEF_DEF_ \"I\" -2; BA_DEF_ \"H\" HEX 0 255; BA_ \"H\" 0xAB; BA_DEF_ \"F\" FLOAT -1.0 2.0; BA_ \"F\" 1.0; BA_DEF_ \"S\" STRING; BA_ \"S\" \"text\"; BA_DEF_ \"E\" ENUM \"A\",\"B\"; BA_ \"E\" 1;",
  )
  assert_eq(diff_database(db, parse_dbc(write_dbc(db))), [])
}

///|
test "writer refuses invalid semantic models" {
  expect_error(
    fn() raise DbcError { write_dbc(database_with([Signal::new("S", 63, 2)])) },
    "signal.bounds",
  )
}

///|
test "writer retains preserved extension" {
  let options = ParseOptions::{
    mode: Permissive,
    limits: ParseLimits::default(),
  }
  let a = parse_dbc_with_options("EV_ custom;\n", options)
  let text = write_dbc(a)
  assert_true(text.contains("EV_ custom;"))
  assert_eq(diff_database(a, parse_dbc_with_options(text, options)), [])
}

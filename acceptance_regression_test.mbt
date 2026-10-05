///|
test "physical unsigned odd integer above 2^52 remains exact" {
  assert_eq(
    physical_to_raw(
      Signal::new("S", 0, 64, maximum=9007199254740991.0),
      4503599627370497.0,
    ),
    Unsigned(4503599627370497UL),
  )
}

///|
test "physical largest exact unsigned integer remains exact" {
  assert_eq(
    physical_to_raw(
      Signal::new("S", 0, 64, maximum=9007199254740991.0),
      9007199254740991.0,
    ),
    Unsigned(9007199254740991UL),
  )
}

///|
test "physical signed odd negative integer above 2^52 remains exact" {
  assert_eq(
    physical_to_raw(
      Signal::new(
        "S",
        0,
        64,
        signed=true,
        minimum=-9007199254740991.0,
        maximum=9007199254740991.0,
      ),
      -4503599627370497.0,
    ),
    Signed(-4503599627370497L),
  )
}

///|
test "physical lowest exact signed integer remains exact" {
  assert_eq(
    physical_to_raw(
      Signal::new(
        "S",
        0,
        64,
        signed=true,
        minimum=-9007199254740991.0,
        maximum=9007199254740991.0,
      ),
      -9007199254740991.0,
    ),
    Signed(-9007199254740991L),
  )
}

///|
test "positive representable half near 2^52 rounds away from zero" {
  assert_eq(
    physical_to_raw(
      Signal::new("S", 0, 64, maximum=9007199254740991.0),
      4503599627370495.5,
    ),
    Unsigned(4503599627370496UL),
  )
}

///|
test "negative representable half near 2^52 rounds away from zero" {
  assert_eq(
    physical_to_raw(
      Signal::new(
        "S",
        0,
        64,
        signed=true,
        minimum=-9007199254740991.0,
        maximum=9007199254740991.0,
      ),
      -4503599627370495.5,
    ),
    Signed(-4503599627370496L),
  )
}

///|
test "quoted object keywords remain database comment text" {
  let db = parse_dbc("CM_ \"BU_\"; CM_ \"BO_\"; CM_ \"SG_\";")
  assert_eq(db.comments.map(fn(c) { c.target }), [
    DatabaseRef,
    DatabaseRef,
    DatabaseRef,
  ])
  assert_eq(db.comments.map(fn(c) { c.text }), ["BU_", "BO_", "SG_"])
}

///|
test "quoted object keyword remains global string attribute value" {
  let db = parse_dbc("BA_DEF_ \"A\" STRING; BA_ \"A\" \"BO_\";")
  assert_eq(db.attribute_value("A", DatabaseRef), Some(Text("BO_")))
  assert_true(validate_database(db).is_empty())
}

///|
test "quoted minus cannot act as numeric sign" {
  expect_error(
    fn() raise DbcError {
      ignore(
        parse_dbc(
          "BO_ 1 A: 1 Vector__XXX\n SG_ X : 0|8@1+ (\"-\"1,0) [0|255] \"\" Vector__XXX\n",
        ),
      )
    },
    "parse.number",
  )
}

///|
test "quoted plus cannot act as numeric sign" {
  expect_error(
    fn() raise DbcError {
      ignore(
        parse_dbc(
          "BO_ 1 A: 1 Vector__XXX\n SG_ X : 0|8@1+ (\"+\"1,0) [0|255] \"\" Vector__XXX\n",
        ),
      )
    },
    "parse.number",
  )
}

///|
test "quoted newline cannot disappear as statement whitespace" {
  expect_error(
    fn() raise DbcError { ignore(parse_dbc("\"\\n\"")) },
    "parse.keyword",
  )
}

///|
test "quoted newline cannot terminate VERSION record" {
  expect_error(
    fn() raise DbcError { ignore(parse_dbc("VERSION \"1\" \"\\n\"")) },
    "parse.trailing",
  )
}

///|
test "attribute name equal to scope keyword remains a name" {
  let db = parse_dbc("BA_DEF_ \"BO_\" STRING; BA_ \"BO_\" \"value\";")
  assert_eq(db.attribute_definitions[0].scope, DatabaseScope)
  assert_eq(db.attribute_value("BO_", DatabaseRef), Some(Text("value")))
}

///|
test "quoted attribute type is rejected" {
  expect_error(
    fn() raise DbcError { ignore(parse_dbc("BA_DEF_ \"A\" \"INT\" 0 1;")) },
    "attribute.type",
  )
}

///|
test "quoted comma cannot delimit attribute enum choices" {
  expect_error(
    fn() raise DbcError {
      ignore(parse_dbc("BA_DEF_ \"A\" ENUM \"Off\" \",\" \"On\";"))
    },
    "parse.expected",
  )
}

///|
test "permissive extension preserves quoted newline as data" {
  let options = ParseOptions::{ ..ParseOptions::default(), mode: Permissive }
  let db = parse_dbc_with_options("UNKNOWN \"\\n\";", options)
  assert_eq(db.unsupported[0].text, "UNKNOWN \"\\n\";")
  assert_eq(
    diff_database(db, parse_dbc_with_options(write_dbc(db), options)).length(),
    0,
  )
}

///|
fn database_with(signals : Array[Signal]) -> Database {
  let db = Database::new()
  db.messages.push(Message::new({ id: 1U, extended: false }, "A", 8, signals~))
  db
}

///|
fn has_issue(db : Database, code : String) -> Bool {
  validate_database(db).iter().any(fn(d) { d.code == code })
}

///|
test "valid basic fixture" {
  assert_eq(validate_database(parse_dbc(basic_text())).length(), 0)
}

///|
test "duplicate id" {
  let db = database_with([])
  db.messages.push(Message::new({ id: 1U, extended: false }, "B", 0))
  assert_true(has_issue(db, "message.duplicate_id"))
}

///|
test "duplicate message name" {
  let db = database_with([])
  db.messages.push(Message::new({ id: 2U, extended: false }, "A", 0))
  assert_true(has_issue(db, "message.duplicate_name"))
}

///|
test "same number standard and extended coexist" {
  let db = database_with([])
  db.messages.push(Message::new({ id: 1U, extended: true }, "B", 0))
  assert_true(!has_issue(db, "message.duplicate_id"))
}

///|
test "unknown transmitter" {
  assert_true(
    has_issue(parse_dbc("BO_ 1 A: 0 Unknown\n"), "message.transmitter"),
  )
}

///|
test "duplicate nodes" {
  assert_true(has_issue(parse_dbc("BU_: X X\n"), "node.duplicate"))
}

///|
test "duplicate signal name" {
  assert_true(
    has_issue(
      database_with([Signal::new("S", 0, 1), Signal::new("S", 1, 1)]),
      "signal.duplicate",
    ),
  )
}

///|
test "zero signal width" {
  assert_true(
    has_issue(database_with([Signal::new("S", 0, 0)]), "signal.length"),
  )
}

///|
test "signal outside payload" {
  assert_true(
    has_issue(database_with([Signal::new("S", 63, 2)]), "signal.bounds"),
  )
}

///|
test "unknown receiver" {
  assert_true(
    has_issue(
      database_with([Signal::new("S", 0, 1, receivers=["X"])]),
      "signal.receiver",
    ),
  )
}

///|
test "invalid physical range" {
  assert_true(
    has_issue(
      database_with([Signal::new("S", 0, 1, minimum=2, maximum=1)]),
      "signal.range",
    ),
  )
}

///|
test "zero factor" {
  assert_true(
    has_issue(
      database_with([Signal::new("S", 0, 1, factor=0)]),
      "signal.factor",
    ),
  )
}

///|
test "nonexclusive overlap" {
  assert_true(
    has_issue(
      database_with([Signal::new("A", 0, 8), Signal::new("B", 7, 8)]),
      "signal.overlap",
    ),
  )
}

///|
test "same branch overlap" {
  assert_true(
    has_issue(
      database_with([
        Signal::new("Mode", 16, 8, multiplex=Multiplexer),
        Signal::new("A", 0, 8, multiplex=Branch(1L)),
        Signal::new("B", 0, 8, multiplex=Branch(1L)),
      ]),
      "signal.overlap",
    ),
  )
}

///|
test "different branch overlap is legal" {
  assert_true(
    !has_issue(
      database_with([
        Signal::new("Mode", 16, 8, multiplex=Multiplexer),
        Signal::new("A", 0, 8, multiplex=Branch(1L)),
        Signal::new("B", 0, 8, multiplex=Branch(2L)),
      ]),
      "signal.overlap",
    ),
  )
}

///|
test "branch without selector" {
  assert_true(
    has_issue(
      database_with([Signal::new("A", 0, 8, multiplex=Branch(1L))]),
      "mux.missing",
    ),
  )
}

///|
test "multiple selectors" {
  assert_true(
    has_issue(
      database_with([
        Signal::new("A", 0, 8, multiplex=Multiplexer),
        Signal::new("B", 8, 8, multiplex=Multiplexer),
      ]),
      "mux.multiple",
    ),
  )
}

///|
test "signed selector" {
  assert_true(
    has_issue(
      database_with([Signal::new("A", 0, 8, multiplex=Multiplexer, signed=true)]),
      "mux.signed",
    ),
  )
}

///|
test "branch out of selector range" {
  assert_true(
    has_issue(
      database_with([
        Signal::new("A", 0, 1, multiplex=Multiplexer),
        Signal::new("B", 8, 8, multiplex=Branch(2L)),
      ]),
      "mux.range",
    ),
  )
}

///|
test "duplicate enum labels" {
  let s = Signal::new("A", 0, 8)
  s.values.push({ raw: 1L, label: "On" })
  s.values.push({ raw: 2L, label: "On" })
  assert_true(has_issue(database_with([s]), "values.label"))
}

///|
test "duplicate enum raws" {
  let s = Signal::new("A", 0, 8)
  s.values.push({ raw: 1L, label: "On" })
  s.values.push({ raw: 1L, label: "Error" })
  assert_true(has_issue(database_with([s]), "values.duplicate"))
}

///|
test "enum outside raw bounds" {
  let s = Signal::new("A", 0, 1)
  s.values.push({ raw: 2L, label: "Two" })
  assert_true(has_issue(database_with([s]), "values.range"))
}

///|
test "unknown comment target" {
  assert_true(has_issue(parse_dbc("CM_ BO_ 1 \"unknown\";"), "comment.target"))
}

///|
test "attribute scope mismatch" {
  assert_true(
    has_issue(
      parse_dbc("BA_DEF_ BO_ \"A\" INT 0 5; BA_ \"A\" 1;"),
      "attribute.scope",
    ),
  )
}

///|
test "attribute default bounds" {
  assert_true(
    has_issue(
      parse_dbc("BA_DEF_ \"A\" INT 0 5; BA_DEF_DEF_ \"A\" 6;"),
      "attribute.value",
    ),
  )
}

///|
test "attribute undefined" {
  assert_true(has_issue(parse_dbc("BA_ \"A\" 1;"), "attribute.undefined"))
}

///|
test "attribute wrong type" {
  assert_true(
    has_issue(
      parse_dbc("BA_DEF_ \"A\" STRING; BA_ \"A\" 1;"),
      "attribute.value",
    ),
  )
}

///|
test "attribute enum invalid index" {
  assert_true(
    has_issue(
      parse_dbc("BA_DEF_ \"A\" ENUM \"Off\",\"On\"; BA_ \"A\" 2;"),
      "attribute.value",
    ),
  )
}

///|
test "attribute default resolution" {
  let db = parse_dbc(
    "BA_DEF_ BO_ \"Cycle\" INT 0 100; BA_DEF_DEF_ \"Cycle\" 10; BO_ 1 A: 0 Vector__XXX\n",
  )
  assert_eq(db.attribute_value("Cycle", MessageRef(1U)), Some(Integer(10L)))
}

///|
test "malformed programmatic identifier" {
  let db = Database::new()
  db.messages.push(Message::new({ id: 4096U, extended: false }, "A", 0))
  assert_true(has_issue(db, "id.range"))
}

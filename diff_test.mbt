///|
test "diff ignores whitespace source positions" {
  let a = parse_dbc(basic_text())
  let b = parse_dbc("\n\n" + basic_text())
  assert_eq(diff_database(a, b), [])
}

///|
test "diff scaling concrete field" {
  let a = parse_dbc(basic_text())
  let b = parse_dbc(basic_text().replace_all(old="0.125", new="0.25"))
  let changes = diff_database(a, b)
  assert_eq(changes.length(), 1)
  assert_eq(changes[0].field, "factor")
  assert_eq(changes[0].signal_name, Some("EngineSpeed"))
  assert_true(changes[0].breaking)
}

///|
test "diff added message" {
  let a = Database::new()
  let b = database_with([])
  assert_eq(diff_database(a, b)[0].kind, Added)
}

///|
test "diff removed message" {
  assert_eq(diff_database(database_with([]), Database::new())[0].kind, Removed)
}

///|
test "diff added signal" {
  let a = database_with([])
  let b = database_with([Signal::new("S", 0, 8)])
  assert_eq(diff_database(a, b)[0].field, "signal")
}

///|
test "diff layout change" {
  let changes = diff_database(
    database_with([Signal::new("S", 0, 8)]),
    database_with([Signal::new("S", 8, 8)]),
  )
  assert_eq(changes[0].field, "start_bit")
}

///|
test "diff enum label change" {
  let a = parse_dbc(basic_text())
  let b = parse_dbc(basic_text().replace_all(old="Drive", new="Forward"))
  assert_eq(diff_database(a, b)[0].field, "values")
}

///|
test "diff metadata attribute change" {
  let a = parse_dbc("BA_DEF_ \"S\" STRING; BA_ \"S\" \"one\";")
  let b = parse_dbc("BA_DEF_ \"S\" STRING; BA_ \"S\" \"two\";")
  assert_eq(diff_database(a, b)[0].field, "metadata")
}

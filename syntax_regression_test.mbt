///|
test "quoted byte order rejected" {
  expect_error(
    fn() raise DbcError {
      parse_dbc("BO_ 1 A: 1 X\n SG_ S : 0|8@\"1\"+ (1,0) [0|255] \"\" X\n")
    },
    "signal.order",
  )
}

///|
test "quoted signedness rejected" {
  expect_error(
    fn() raise DbcError {
      parse_dbc("BO_ 1 A: 1 X\n SG_ S : 0|8@1\"+\" (1,0) [0|255] \"\" X\n")
    },
    "signal.sign",
  )
}

///|
test "empty quoted extension preserved" {
  let db = parse_dbc_with_options("EV_ \"\";", {
    mode: Permissive,
    limits: ParseLimits::default(),
  })
  assert_eq(db.unsupported[0].text, "EV_ \"\";")
}

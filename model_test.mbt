///|
test "standard and extended identity" {
  let a = FrameId::new(0x123U)
  let b = FrameId::new(0x123U, extended=true)
  assert_true(a != b)
  assert_eq(b.to_dbc(), 0x80000123U)
  assert_eq(frame_id_from_dbc(b.to_dbc()), b)
}

///|
test "identifier reserved flags" {
  expect_error(
    fn() raise DbcError { frame_id_from_dbc(0x40000000U) },
    "id.flags",
  )
  expect_error(fn() raise DbcError { FrameId::new(0x800U) }, "id.range")
  expect_error(
    fn() raise DbcError { FrameId::new(0x20000000U, extended=true) },
    "id.range",
  )
}

///|
test "database queries preserve message context" {
  let db = Database::new()
  db.messages.push(
    Message::new(FrameId::new(1U), "A", 1, signals=[Signal::new("S", 0, 8)]),
  )
  assert_eq(db.find_signals("S").length(), 1)
  assert_true(db.message_by_name("A") is Some(_))
  assert_true(db.message_by_name("B") is None)
  assert_true(db.message_by_id(FrameId::new(1U)) is Some(_))
}

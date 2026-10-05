///|
test "statistics core inventory" {
  let stats = inspect_database(parse_dbc(basic_text()))
  assert_eq(stats.nodes, 2)
  assert_eq(stats.messages, 1)
  assert_eq(stats.signals, 2)
  assert_eq(stats.standard_messages, 1)
  assert_eq(stats.value_descriptions, 2)
  assert_eq(stats.errors, 0)
}

///|
test "FD-sized statistics distinguish byte length" {
  let db = Database::new()
  db.messages.push(Message::new({ id: 1U, extended: true }, "FD", 64))
  let stats = inspect_database(db)
  assert_eq(stats.fd_sized_messages, 1)
  assert_eq(stats.extended_messages, 1)
  assert_eq(stats.classic_sized_messages, 0)
}

///|
test "statistics actual errors" {
  let stats = inspect_database(database_with([Signal::new("A", 63, 2)]))
  assert_eq(stats.errors, 1)
}

///|
test "layout Intel boundary" {
  let cells = message_layout(
    Message::new({ id: 1U, extended: false }, "A", 2, signals=[
      Signal::new("X", 7, 2),
    ]),
  )
  assert_eq(cells[7].owners, ["X"])
  assert_eq(cells[8].owners, ["X"])
  assert_eq(cells[6].owners, [])
}

///|
test "layout Motorola boundary" {
  let cells = message_layout(
    Message::new({ id: 1U, extended: false }, "A", 2, signals=[
      Signal::new("X", 0, 2, byte_order=Motorola),
    ]),
  )
  assert_eq(cells[0].owners, ["X"])
  assert_eq(cells[15].owners, ["X"])
}

///|
test "layout exclusive owners displayed" {
  assert_eq(message_layout(mux_message())[8].owners, ["A(m0)", "B(m1)", "C(m2)"])
}

///|
test "render layout actual signal labels" {
  let rendered = render_layout(mux_message())
  assert_true(rendered.contains("Mode(M)"))
  assert_true(rendered.contains("Byte 2:"))
}

///|
test "empty frame layout" {
  assert_eq(message_layout(Message::new({ id: 1U, extended: false }, "A", 0)), [])
}

///|
test "invalid layout length" {
  expect_error(
    fn() raise DbcError {
      message_layout(Message::new({ id: 1U, extended: false }, "A", 65))
    },
    "message.length",
  )
}

///|
test "multiplex stats" {
  let db = Database::new()
  db.messages.push(mux_message())
  assert_eq(inspect_database(db).multiplexed_messages, 1)
}

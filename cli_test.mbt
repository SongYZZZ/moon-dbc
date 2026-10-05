///|
test "CLI help no arguments" {
  assert_eq(execute_cli(parse_cli_arguments([]), "").exit_code, 0)
}

///|
test "CLI version" {
  assert_eq(
    execute_cli(parse_cli_arguments(["--version"]), "").text,
    "moon-dbc 0.1.0",
  )
}

///|
test "CLI unknown flag" {
  expect_error(
    fn() raise DbcError { parse_cli_arguments(["inspect", "x", "--fake"]) },
    "cli.arguments",
  )
}

///|
test "CLI missing file" {
  expect_error(
    fn() raise DbcError { parse_cli_arguments(["inspect"]) },
    "cli.arguments",
  )
}

///|
test "CLI hex odd length" {
  expect_error(fn() raise DbcError { parse_frame_hex("ABC") }, "cli.hex")
}

///|
test "CLI hex invalid character" {
  expect_error(fn() raise DbcError { parse_frame_hex("XX") }, "cli.hex")
}

///|
test "CLI hex parser render inverse" {
  assert_eq(frame_hex(parse_frame_hex("0123abcd")), "0123ABCD")
}

///|
test "CLI inspect real counts" {
  assert_true(
    execute_cli(parse_cli_arguments(["inspect", "basic.dbc"]), basic_text()).text.contains(
      "Signals: 2",
    ),
  )
}

///|
test "CLI validate status" {
  assert_eq(
    execute_cli(parse_cli_arguments(["validate", "basic.dbc"]), basic_text()).exit_code,
    0,
  )
}

///|
test "CLI decode physical and label" {
  assert_true(
    execute_cli(
      parse_cli_arguments(["decode", "x", "0x123", "E02E030000000000"]),
      basic_text(),
    ).text.contains("value=1500 rpm"),
  )
}

///|
test "CLI decode JSON exact raw string" {
  let text = execute_cli(
      parse_cli_arguments(["decode", "x", "0x123", "E02E030000000000", "--json"]),
      basic_text(),
    ).text
  assert_true(text.contains("\"raw\":\"12000\""))
}

///|
test "CLI encode physical" {
  assert_eq(
    execute_cli(
      parse_cli_arguments(["encode", "x", "291", "EngineSpeed=1500", "Gear=3"]),
      basic_text(),
    ).text,
    "E02E030000000000",
  )
}

///|
test "CLI encode label" {
  assert_eq(
    execute_cli(
      parse_cli_arguments([
        "encode", "x", "291", "EngineSpeed=1500", "Gear=label:Drive",
      ]),
      basic_text(),
    ).text,
    "E02E030000000000",
  )
}

///|
test "CLI encode exact raw" {
  assert_eq(
    execute_cli(
      parse_cli_arguments([
        "encode", "x", "291", "--raw", "EngineSpeed=12000", "Gear=3",
      ]),
      basic_text(),
    ).text,
    "E02E030000000000",
  )
}

///|
test "CLI layout dynamically rendered" {
  assert_true(
    execute_cli(parse_cli_arguments(["layout", "x", "291"]), basic_text()).text.contains(
      "EngineSpeed",
    ),
  )
}

///|
test "CLI diff identical status" {
  assert_eq(
    execute_cli(
      parse_cli_arguments(["diff", "a", "b"]),
      basic_text(),
      second_source=basic_text(),
    ).exit_code,
    0,
  )
}

///|
test "CLI diff changed status" {
  assert_eq(
    execute_cli(
      parse_cli_arguments(["diff", "a", "b"]),
      basic_text(),
      second_source=basic_text().replace_all(old="0.125", new="0.25"),
    ).exit_code,
    1,
  )
}

///|
test "CLI normalization roundtrip" {
  assert_eq(
    diff_database(
      parse_dbc(basic_text()),
      parse_dbc(
        execute_cli(parse_cli_arguments(["normalize", "x"]), basic_text()).text,
      ),
    ),
    [],
  )
}

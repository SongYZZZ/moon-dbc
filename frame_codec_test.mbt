///|
fn mux_message() -> Message {
  Message::new({ id: 5U, extended: false }, "Mux", 3, signals=[
    Signal::new("Mode", 0, 8, maximum=255, multiplex=Multiplexer),
    Signal::new("Common", 16, 8, maximum=255),
    Signal::new("A", 8, 8, maximum=255, multiplex=Branch(0L)),
    Signal::new("B", 8, 8, maximum=255, multiplex=Branch(1L)),
    Signal::new("C", 8, 8, maximum=255, multiplex=Branch(2L)),
  ])
}

///|
fn mux_decode(mode : Byte) -> DecodedMessage raise DbcError {
  compile_message(mux_message()).decode({
    frame_id: { id: 5U, extended: false },
    payload: [mode, 42, 11],
  })
}

///|
test "mux zero only branch A" {
  assert_eq(mux_decode(0).signals.map(fn(s) { s.name }), ["Mode", "Common", "A"])
}

///|
test "mux one only branch B" {
  assert_eq(mux_decode(1).signals.map(fn(s) { s.name }), ["Mode", "Common", "B"])
}

///|
test "mux two only branch C" {
  assert_eq(mux_decode(2).signals.map(fn(s) { s.name }), ["Mode", "Common", "C"])
}

///|
test "unknown mux keeps always signals with warning" {
  let out = mux_decode(9)
  assert_eq(out.signals.map(fn(s) { s.name }), ["Mode", "Common"])
  assert_eq(out.diagnostics[0].code, "mux.unknown")
}

///|
test "mux encode active branch" {
  let out = encode_message(mux_message(), [
    { name: "Mode", value: Physical(1) },
    { name: "Common", value: Physical(11) },
    { name: "B", value: Physical(42) },
  ])
  assert_eq(out.frame.payload, [1, 42, 11])
}

///|
test "missing selector input" {
  expect_error(
    fn() raise DbcError { encode_message(mux_message(), []) },
    "codec.missing_input",
  )
}

///|
test "inactive branch input" {
  expect_error(
    fn() raise DbcError {
      encode_message(mux_message(), [
        { name: "Mode", value: Physical(1) },
        { name: "Common", value: Physical(11) },
        { name: "A", value: Physical(42) },
        { name: "B", value: Physical(2) },
      ])
    },
    "codec.inactive_input",
  )
}

///|
test "missing active branch" {
  expect_error(
    fn() raise DbcError {
      encode_message(mux_message(), [
        { name: "Mode", value: Physical(1) },
        { name: "Common", value: Physical(11) },
      ])
    },
    "codec.missing_input",
  )
}

///|
test "unknown assignment" {
  expect_error(
    fn() raise DbcError {
      encode_message(mux_message(), [{ name: "No", value: Physical(1) }])
    },
    "codec.unknown_signal",
  )
}

///|
test "duplicate assignment" {
  expect_error(
    fn() raise DbcError {
      encode_message(mux_message(), [
        { name: "Mode", value: Physical(1) },
        { name: "Mode", value: Physical(2) },
      ])
    },
    "codec.duplicate_input",
  )
}

///|
test "frame length mismatch" {
  expect_error(
    fn() raise DbcError {
      compile_message(mux_message()).decode({
        frame_id: { id: 5U, extended: false },
        payload: [0],
      })
    },
    "codec.payload_length",
  )
}

///|
test "frame extended identity mismatch" {
  expect_error(
    fn() raise DbcError {
      compile_message(mux_message()).decode({
        frame_id: { id: 5U, extended: true },
        payload: [0, 0, 0],
      })
    },
    "codec.frame_id",
  )
}

///|
test "database unknown ID" {
  expect_error(
    fn() raise DbcError {
      decode_frame(Database::new(), {
        frame_id: { id: 1U, extended: false },
        payload: [],
      })
    },
    "codec.unknown_id",
  )
}

///|
test "enumeration label encode" {
  let m = parse_dbc(basic_text()).messages[0]
  let out = encode_message(m, [
    { name: "EngineSpeed", value: Physical(1500) },
    { name: "Gear", value: Label("Drive") },
  ])
  assert_eq(out.frame.payload, [0xE0, 0x2E, 3, 0, 0, 0, 0, 0])
  assert_eq(
    compile_message(m).decode(out.frame).signals[1].label,
    Some("Drive"),
  )
}

///|
test "unknown label" {
  let m = parse_dbc(basic_text()).messages[0]
  expect_error(
    fn() raise DbcError {
      encode_message(m, [
        { name: "EngineSpeed", value: Physical(0) },
        { name: "Gear", value: Label("Unknown") },
      ])
    },
    "codec.label",
  )
}

///|
test "decoded range warning" {
  let m = Message::new({ id: 1U, extended: false }, "A", 1, signals=[
    Signal::new("S", 0, 8, maximum=10),
  ])
  let out = compile_message(m).decode({ frame_id: m.frame_id, payload: [11] })
  assert_true(out.signals[0].out_of_range)
  assert_eq(out.diagnostics[0].code, "codec.decoded_range")
}

///|
test "Warn range policy preserves warning" {
  let m = Message::new({ id: 1U, extended: false }, "A", 1, signals=[
    Signal::new("S", 0, 8, maximum=10),
  ])
  let out = encode_message(
    m,
    [{ name: "S", value: Physical(11) }],
    range_policy=Warn,
  )
  assert_eq(out.diagnostics[0].code, "codec.encoded_range")
  assert_eq(out.frame.payload, [11])
}

///|
test "compiled snapshot isolated from caller mutation" {
  let m = mux_message()
  let compiled = compile_message(m)
  m.signals.clear()
  assert_eq(
    compiled.decode({ frame_id: m.frame_id, payload: [0, 42, 11] }).signals.length(),
    3,
  )
}

///|
test "raw signed negative frame" {
  let m = Message::new({ id: 1U, extended: false }, "A", 2, signals=[
    Signal::new(
      "S",
      7,
      12,
      signed=true,
      byte_order=Motorola,
      minimum=-2048,
      maximum=2047,
    ),
  ])
  let compiled = compile_message(m)
  let out = compiled.encode([{ name: "S", value: Raw(Signed(-1L)) }])
  assert_eq(out.frame.payload, [0xFF, 0xF0])
  assert_eq(compiled.decode(out.frame).signals[0].raw, Signed(-1L))
}

///|
test "empty message frame" {
  let m = Message::new({ id: 1U, extended: false }, "Empty", 0)
  assert_eq(encode_message(m, []).frame.payload, [])
}

///|
test "deterministic randomized raw layouts and values" {
  let mut seed = 0x12345678U
  for order in [ByteOrder::Intel, ByteOrder::Motorola] {
    for width = 1; width <= 64; width = width + 1 {
      for sample = 0; sample < 12; sample = sample + 1 {
        seed = seed * 1664525U + 1013904223U
        let start = if order == Intel { sample % 8 } else { 7 - sample % 8 }
        let s = Signal::new("S", start, width, byte_order=order)
        let mask = if width == 64 {
          0xFFFFFFFFFFFFFFFFUL
        } else {
          (1UL << width) - 1UL
        }
        let raw = ((seed.to_uint64() << 32) | (seed ^ 0xA5A5A5A5U).to_uint64()) &
          mask
        let payload : Array[Byte] = Array::make(16, 0xA5)
        encode_signal_raw(s, payload, Unsigned(raw))
        assert_eq(decode_signal_raw(s, payload), Unsigned(raw))
      }
    }
  }
}

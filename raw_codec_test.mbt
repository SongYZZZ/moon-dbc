///|
test "Intel manual 16-bit" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 0, 16), [0x34, 0x12]),
    Unsigned(0x1234UL),
  )
}

///|
test "Motorola manual 16-bit" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 7, 16, byte_order=Motorola), [0x12, 0x34]),
    Unsigned(0x1234UL),
  )
}

///|
test "Intel manual unaligned nine bits" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 2, 9), [0xBC, 0x04]),
    Unsigned(0x12FUL),
  )
}

///|
test "Motorola manual unaligned five bits" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 2, 5, byte_order=Motorola), [0x05, 0x40]),
    Unsigned(0x15UL),
  )
}

///|
test "Motorola manual bit zero boundary" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 0, 9, byte_order=Motorola), [0x01, 0xAB]),
    Unsigned(0x1ABUL),
  )
}

///|
test "Intel signed 12-bit minus one" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 0, 12, signed=true), [0xFF, 0x0F]),
    Signed(-1L),
  )
}

///|
test "Motorola signed 12-bit minus one" {
  assert_eq(
    decode_signal_raw(
      Signal::new("S", 7, 12, byte_order=Motorola, signed=true),
      [0xFF, 0xF0],
    ),
    Signed(-1L),
  )
}

///|
test "one-bit signed negative" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 0, 1, signed=true), [1]),
    Signed(-1L),
  )
}

///|
test "signed 8-bit minimum" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 0, 8, signed=true), [0x80]),
    Signed(-128L),
  )
}

///|
test "signed 12-bit minimum" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 0, 12, signed=true), [0, 0x08]),
    Signed(-2048L),
  )
}

///|
test "signed 16-bit maximum" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 0, 16, signed=true), [0xFF, 0x7F]),
    Signed(32767L),
  )
}

///|
test "signed 24-bit minimum" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 0, 24, signed=true), [0, 0, 0x80]),
    Signed(-8388608L),
  )
}

///|
test "signed 32-bit minimum" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 0, 32, signed=true), [0, 0, 0, 0x80]),
    Signed(-2147483648L),
  )
}

///|
test "unsigned 64-bit maximum exact" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 0, 64), Array::make(8, 0xFF)),
    Unsigned(0xFFFFFFFFFFFFFFFFUL),
  )
}

///|
test "signed 64-bit minimum exact" {
  assert_eq(
    decode_signal_raw(
      Signal::new("S", 7, 64, signed=true, byte_order=Motorola),
      [0x80, 0, 0, 0, 0, 0, 0, 0],
    ),
    Signed(-0x8000000000000000L),
  )
}

///|
test "Motorola manual 32-bit" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 7, 32, byte_order=Motorola), [
      0x12, 0x34, 0x56, 0x78,
    ]),
    Unsigned(0x12345678UL),
  )
}

///|
test "preserve unrelated bits" {
  let payload : Array[Byte] = [0xFF, 0xAA]
  encode_signal_raw(Signal::new("S", 2, 2), payload, Unsigned(0UL))
  assert_eq(payload, [0xF3, 0xAA])
}

///|
test "Motorola encode matches independent vector" {
  let payload : Array[Byte] = [0, 0]
  encode_signal_raw(
    Signal::new("S", 2, 5, byte_order=Motorola),
    payload,
    Unsigned(0x15UL),
  )
  assert_eq(payload, [5, 0x40])
}

///|
test "unsigned overflow rejected before mutation" {
  let payload : Array[Byte] = [0xAA]
  expect_error(
    fn() raise DbcError {
      encode_signal_raw(Signal::new("S", 0, 7), payload, Unsigned(128UL))
    },
    "codec.raw_range",
  )
  assert_eq(payload, [0xAA])
}

///|
test "signed overflow" {
  expect_error(
    fn() raise DbcError {
      encode_signal_raw(Signal::new("S", 0, 8, signed=true), [0], Signed(128L))
    },
    "codec.raw_range",
  )
}

///|
test "raw signedness mismatch" {
  expect_error(
    fn() raise DbcError {
      encode_signal_raw(Signal::new("S", 0, 8), [0], Signed(1L))
    },
    "codec.raw_type",
  )
}

///|
test "factor and offset" {
  assert_eq(
    raw_to_physical(
      Signal::new("S", 0, 8, factor=0.5, offset=-40),
      Unsigned(100UL),
    ),
    10.0,
  )
}

///|
test "physical exact raw" {
  assert_eq(
    physical_to_raw(Signal::new("S", 0, 16, factor=0.125, maximum=8000), 1500),
    Unsigned(12000UL),
  )
}

///|
test "rounding positive tie away" {
  assert_eq(
    physical_to_raw(Signal::new("S", 0, 8, maximum=255), 1.5),
    Unsigned(2UL),
  )
}

///|
test "rounding negative tie away" {
  assert_eq(
    physical_to_raw(
      Signal::new("S", 0, 8, signed=true, minimum=-128, maximum=127),
      -1.5,
    ),
    Signed(-2L),
  )
}

///|
test "physical default rejects range" {
  expect_error(
    fn() raise DbcError {
      physical_to_raw(Signal::new("S", 0, 8, maximum=10), 11)
    },
    "codec.physical_range",
  )
}

///|
test "physical explicit clamp" {
  assert_eq(
    physical_to_raw(Signal::new("S", 0, 8, maximum=10), 11, range_policy=Clamp),
    Unsigned(10UL),
  )
}

///|
test "physical explicit ignore" {
  assert_eq(
    physical_to_raw(Signal::new("S", 0, 8, maximum=10), 11, range_policy=Ignore),
    Unsigned(11UL),
  )
}

///|
test "negative factor" {
  assert_eq(
    physical_to_raw(
      Signal::new("S", 0, 8, factor=-2, offset=100, minimum=-410, maximum=100),
      80,
    ),
    Unsigned(10UL),
  )
}

///|
test "precision boundary uses raw API" {
  expect_error(
    fn() raise DbcError {
      physical_to_raw(Signal::new("S", 0, 64, maximum=1.0e20), 1.0e18)
    },
    "codec.precision",
  )
}

///|
test "zero factor conversion" {
  expect_error(
    fn() raise DbcError { physical_to_raw(Signal::new("S", 0, 8, factor=0), 0) },
    "signal.factor",
  )
}

///|
test "range after quantization" {
  expect_error(
    fn() raise DbcError {
      physical_to_raw(Signal::new("S", 0, 8, factor=2, maximum=3), 3)
    },
    "codec.quantized_range",
  )
}

///|
test "CAN FD final byte" {
  assert_eq(
    decode_signal_raw(Signal::new("S", 504, 8), Array::make(64, 0xA5)),
    Unsigned(0xA5UL),
  )
}

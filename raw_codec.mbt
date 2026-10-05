///|
/// Decode an exact signed or unsigned integer from a checked DBC layout.
pub fn decode_signal_raw(
  signal : Signal,
  payload : Array[Byte],
) -> RawValue raise DbcError {
  let positions = signal_bits(signal, payload.length())
  let bits = match signal.byte_order {
    Intel => extract_intel(payload, positions)
    Motorola => extract_motorola(payload, positions)
  }
  if !signal.signed {
    return Unsigned(bits)
  }
  if signal.bit_length == 64 {
    return Signed(bits.reinterpret_as_int64())
  }
  let sign = 1UL << (signal.bit_length - 1)
  Signed(
    (if (bits & sign) != 0UL {
      bits | (0xFFFFFFFFFFFFFFFFUL << signal.bit_length)
    } else {
      bits
    }).reinterpret_as_int64(),
  )
}

///|
fn extract_intel(payload : Array[Byte], positions : Array[Int]) -> UInt64 {
  let mut bits = 0UL
  for weight, position in positions {
    let bit = (payload[position / 8].to_int() >> (position % 8)) & 1
    bits = bits | (bit.to_uint64() << weight)
  }
  bits
}

///|
fn extract_motorola(payload : Array[Byte], positions : Array[Int]) -> UInt64 {
  let mut bits = 0UL
  for position in positions {
    let bit = (payload[position / 8].to_int() >> (position % 8)) & 1
    bits = (bits << 1) | bit.to_uint64()
  }
  bits
}

///|
fn checked_raw_bits(signal : Signal, raw : RawValue) -> UInt64 raise DbcError {
  if signal.bit_length < 1 || signal.bit_length > 64 {
    fail("signal.length", "integer signals must be 1..64 bits")
  }
  match (signal.signed, raw) {
    (true, Signed(n)) => {
      if !integer_fits(signal, n) {
        fail("codec.raw_range", "signed raw value does not fit signal")
      }
      n.reinterpret_as_uint64()
    }
    (false, Unsigned(n)) => {
      if signal.bit_length < 64 && n >= 1UL << signal.bit_length {
        fail("codec.raw_range", "unsigned raw value does not fit signal")
      }
      n
    }
    _ => {
      fail("codec.raw_type", "raw signedness must match signal")
      0UL
    }
  }
}

///|
/// Write only the signal's occupied bits. Validate all inputs before mutating.
pub fn encode_signal_raw(
  signal : Signal,
  payload : Array[Byte],
  raw : RawValue,
) -> Unit raise DbcError {
  let positions = signal_bits(signal, payload.length())
  let bits = checked_raw_bits(signal, raw)
  for i, position in positions {
    let weight = match signal.byte_order {
      Intel => i
      Motorola => signal.bit_length - 1 - i
    }
    let bit = ((bits >> weight) & 1UL).to_int()
    let byte_index = position / 8
    let mask = 1 << (position % 8)
    payload[byte_index] = ((payload[byte_index].to_int() & (255 ^ mask)) |
    (bit << (position % 8))).to_byte()
  }
}

///|
/// Checked linear conversion; exact raw values remain available separately.
pub fn raw_to_physical(
  signal : Signal,
  raw : RawValue,
) -> Double raise DbcError {
  ignore(checked_raw_bits(signal, raw))
  if !finite(signal.factor) || signal.factor == 0.0 || !finite(signal.offset) {
    fail("signal.factor", "invalid signal scaling")
  }
  let n = match raw {
    Unsigned(v) => v.to_double()
    Signed(v) => v.to_double()
  }
  let result = n * signal.factor + signal.offset
  if !finite(result) {
    fail("codec.physical_overflow", "physical value is nonfinite")
  }
  result
}

///|
/// Physical input quantizes to nearest raw integer, ties away from zero.
/// Values beyond Double's exact integer range require the raw API.
pub fn physical_to_raw(
  signal : Signal,
  physical : Double,
  range_policy? : RangePolicy = Reject,
) -> RawValue raise DbcError {
  if !finite(physical) {
    fail("codec.nonfinite", "physical value must be finite")
  }
  if !finite(signal.factor) || signal.factor == 0.0 || !finite(signal.offset) {
    fail("signal.factor", "invalid signal scaling")
  }
  if !finite(signal.minimum) ||
    !finite(signal.maximum) ||
    signal.minimum > signal.maximum {
    fail("signal.range", "invalid physical range")
  }
  let mut value = physical
  if value < signal.minimum || value > signal.maximum {
    match range_policy {
      Reject =>
        fail("codec.physical_range", "physical value exceeds declared range")
      Clamp =>
        value = if value < signal.minimum {
          signal.minimum
        } else {
          signal.maximum
        }
      Ignore | Warn => ()
    }
  }
  let unrounded = (value - signal.offset) / signal.factor
  if !finite(unrounded) || unrounded.abs() > 9007199254740991.0 {
    fail("codec.precision", "use raw API outside exact Double integer range")
  }
  let rounded = if unrounded < 0.0 {
    -@double.floor(-unrounded + 0.5)
  } else {
    @double.floor(unrounded + 0.5)
  }
  let raw = if signal.signed {
    Signed(rounded.to_int64())
  } else {
    if rounded < 0.0 {
      fail("codec.raw_range", "negative raw for unsigned signal")
    }
    Unsigned(rounded.to_uint64())
  }
  ignore(checked_raw_bits(signal, raw))
  let quantized = raw_to_physical(signal, raw)
  if (range_policy == Reject || range_policy == Clamp) &&
    (quantized < signal.minimum || quantized > signal.maximum) {
    fail(
      "codec.quantized_range", "nearest raw integer lies outside physical range",
    )
  }
  raw
}

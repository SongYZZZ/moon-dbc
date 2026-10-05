///|
/// Ordered payload positions, LSB first for Intel and MSB first for Motorola.
/// Rejects invalid widths/start positions before allocating or shifting.
pub fn signal_bits(
  signal : Signal,
  payload_length : Int,
) -> Array[Int] raise DbcError {
  if payload_length < 0 || payload_length > 64 {
    fail("message.length", "payload must be 0..64 bytes")
  }
  if signal.bit_length < 1 || signal.bit_length > 64 {
    fail("signal.length", "integer signals must be 1..64 bits")
  }
  if signal.start_bit < 0 || signal.start_bit >= payload_length * 8 {
    fail("signal.bounds", "start bit exceeds payload")
  }
  let positions = []
  let mut position = signal.start_bit
  for i = 0; i < signal.bit_length; i = i + 1 {
    if position < 0 || position >= payload_length * 8 {
      fail("signal.bounds", "signal exceeds payload")
    }
    positions.push(position)
    position = match signal.byte_order {
      Intel => position + 1
      Motorola => if position % 8 == 0 { position + 15 } else { position - 1 }
    }
  }
  positions
}

///|
fn active_together(a : MultiplexInfo, b : MultiplexInfo) -> Bool {
  match (a, b) {
    (Branch(x), Branch(y)) => x == y
    _ => true
  }
}

///|
/// Return the exact intersecting payload bits, respecting mutually exclusive branches.
pub fn signal_overlap(
  a : Signal,
  b : Signal,
  payload_length : Int,
) -> Array[Int] raise DbcError {
  if !active_together(a.multiplex, b.multiplex) {
    return []
  }
  let x = signal_bits(a, payload_length)
  let y = signal_bits(b, payload_length)
  x.filter(fn(bit) { y.contains(bit) })
}

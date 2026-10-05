///|
test "manual Motorola sawtooth minimum experiment" {
  assert_eq(signal_bits(Signal::new("S", 2, 5, byte_order=Motorola), 2), [
    2, 1, 0, 15, 14,
  ])
}

///|
test "manual Intel unaligned positions" {
  assert_eq(signal_bits(Signal::new("S", 2, 9), 2), [2, 3, 4, 5, 6, 7, 8, 9, 10])
}

///|
test "Motorola start at bit zero crosses immediately" {
  assert_eq(signal_bits(Signal::new("S", 0, 9, byte_order=Motorola), 2), [
    0, 15, 14, 13, 12, 11, 10, 9, 8,
  ])
}

///|
test "single byte Motorola positions" {
  assert_eq(signal_bits(Signal::new("S", 7, 8, byte_order=Motorola), 1), [
    7, 6, 5, 4, 3, 2, 1, 0,
  ])
}

///|
test "exclusive branches do not overlap" {
  assert_eq(
    signal_overlap(
      Signal::new("A", 0, 8, multiplex=Branch(0L)),
      Signal::new("B", 0, 8, multiplex=Branch(1L)),
      1,
    ),
    [],
  )
}

///|
test "always active overlaps branch" {
  assert_eq(
    signal_overlap(
      Signal::new("A", 0, 8),
      Signal::new("B", 2, 2, multiplex=Branch(1L)),
      1,
    ),
    [2, 3],
  )
}

///|
test "Motorola last frame byte overflow" {
  expect_error(
    fn() raise DbcError {
      signal_bits(Signal::new("S", 0, 2, byte_order=Motorola), 1)
    },
    "signal.bounds",
  )
}

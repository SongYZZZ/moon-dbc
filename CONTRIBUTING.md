# Contributing

Discuss behavior changes in an issue on SongYZZZ/moon-dbc. Contributions are licensed
under Apache-2.0. State the source/license of fixtures and reference behavior; never
submit proprietary DBC files or copy implementation code without provenance review.

Use current MoonBit configuration and core APIs. Keep public types documented;
keep parser state private. Run moon fmt, moon check --deny-warn, moon test --deny-warn,
moon info, and inspect interface changes. Codec changes require independent expected
payloads or a recorded oracle comparison, plus boundary tests for both byte orders.
Every supported syntax addition needs writer/round-trip tests and an updated support
table. Unsupported critical extensions must fail explicitly.

Use meaningful incremental commits. Do not add duplicate tests, empty wrappers,
generated fixtures or source padding to satisfy a size target. Benchmarks report
actual environment/results; unit tests should not depend on timing or live networks.

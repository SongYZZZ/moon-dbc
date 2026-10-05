# Changelog

## 0.1.0 — 2026-10-05

- Original typed DBC parser/model with resource budgets and structured diagnostics.
- Intel/Motorola 1–64-bit exact raw codecs, signed interpretation, scaling/range rules.
- Basic multiplex activation, branch-aware layout validation and compiled snapshots.
- Value descriptions, scoped comments, attribute schemas/defaults/assignments.
- Deterministic semantic writer, revision diff, database inventory and bit layout.
- Native/JS/Wasm file CLI and runnable library examples.
- 203 unit tests, deterministic raw round-trips, independent interoperability and
  actual native benchmarks. GitHub CI configured; run status is separately reported.
- Acceptance review fixed physical integer rounding above 2^52 and quoted token
  handling in metadata, numeric signs and preserved extensions before publication.

# Executed verification

2026-10-05: 187 MoonBit tests passed, 0 failed on default wasm-gc. Native/JS were
also executed; final backend counts are recorded in COMPLETION_REPORT.md.
These are distinct named cases covering syntax, metadata, semantic validation,
bit layouts, raw codec, scaling, mux, writer, diff, CLI and parser hardening.
The randomized test performs 1536 deterministic layouts/values (fixed seed
0x12345678, both byte orders, widths 1..64, twelve samples per width). Those
iterations are additional assertions, not inflated test counts.

Manual independent vectors include Intel start=2 length=9 -> BC04 -> raw 0x12F,
Motorola start=2 length=5 -> 0540 -> raw 0x15, Motorola start=0 length=9 -> 01AB,
and signed 12-bit FFF -> -1. Full-width 64-bit boundaries are tested exactly.

Real interoperability: 37/37 cantools 44.1.0 vectors. See COMPATIBILITY.md and
interop-results.json. Oracle-generated Motorola vectors include signed extrema
and zero/positive/negative values. Two unrelated implementations must agree.
No oracle library is linked into MoonDBC.

Real CLI smoke: scripts/smoke.ps1 executes 13 cases including positive paths,
invalid layout status 1, bad hex status 2 and missing file status 2. All file fixture
tests use original small databases. Default/JS/native CLI runs have been executed.

Quality commands: moon fmt --check, moon check --deny-warn, moon test --deny-warn,
moon info, moon build, moon build --target native --release cmd/main, moon package.
Benchmarks run separately with moon bench --target native --release and are not
counted as unit tests. README commands are reproduced through actual process runs.
No coverage percentage is claimed.

The CI workflow repeats format, check, build, tests in three backends, examples and
six CLI commands on Ubuntu. A configured workflow is distinct from a successful
remote run; COMPLETION_REPORT records the actual observed status.

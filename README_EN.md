# MoonDBC

An independently implemented MoonBit DBC toolkit for CAN / CAN FD database
parsing, validation, exact integer frame codecs, multiplexing and a file CLI.
Author: 宋永振 / SongYZZZ. Repository: https://github.com/SongYZZZ/moon-dbc.
Apache-2.0. [Chinese README](README.md)

It serves automotive, robotics and embedded test applications which need to turn
captured payloads into engineering values, construct test frames, inspect layouts
or compare database revisions. Hardware drivers and protocol stacks remain separate.

## Implemented

- Typed database, nodes, messages, signals, attributes, comments and diagnostics.
- Bounded tokenizer/parser with source locations and strict/permissive modes.
- Intel / DBC Motorola integer signals, signed two's complement, 1–64 bits.
- Exact signed/unsigned raw values, scaling, rounding and explicit range policies.
- Value labels and basic M / mN multiplexing with branch-aware overlap validation.
- Standard/extended arbitration IDs and byte payloads from 0 through 64.
- Deterministic semantic writer, field-based revision diff, inventory and bit layout.
- Reusable compiled message snapshots for repeated codec operations.
- inspect / validate / decode / encode / diff / layout / normalize CLI.

## Build and use

Verified with moonc v0.10.9, moon 0.1.20260819 on Windows 11:

```powershell
moon update
moon check
moon test
moon fmt --check
moon build
moon info
pwsh -NoProfile -File scripts/build-cli.ps1
.\dist\moon-dbc.exe inspect tests/fixtures/basic.dbc
.\dist\moon-dbc.exe decode tests/fixtures/basic.dbc 0x123 E02E030000000000
.\dist\moon-dbc.exe encode tests/fixtures/basic.dbc 0x123 EngineSpeed=1500 Gear=3
.\dist\moon-dbc.exe layout tests/fixtures/multiplex.dbc 293
moon run examples/basic
moon run examples/multiplex
```

Actual decode output:

```text
Message: EngineData (DBC ID 291)
EngineSpeed: raw=12000 value=1500 rpm
Gear: raw=3 value=3  (Drive)
```

Mooncakes module: SongYZZZ/moon-dbc 0.1.0. `moon package` has validated the name
and metadata. See [Completion Report](docs/COMPLETION_REPORT.md) for the actual
publication status. The only external module is official moonbitlang/x 0.5.1 for
CLI IO/exit. Python/cantools is never a runtime dependency.

## Library

Import `SongYZZZ/moon-dbc` as `dbc`. See the complete runnable examples and
`pkg.generated.mbti`. Public operations raise `DbcError::Failure(Diagnostic)`.
Queries return Option. `compile_message` snapshots arrays and caches positions.

## Support boundary

| Syntax | Status |
|---|---|
| VERSION, BU_, BO_, SG_ | Documented core grammar |
| NS_ | Namespace declarations terminated by BS_ |
| BS_ | Empty section only |
| CM_ | Database / node / message / signal |
| VAL_ | Raw label keys limited to Int64 |
| BA_DEF_, BA_DEF_DEF_, BA_ | INT / HEX / FLOAT / STRING / ENUM, four scopes |
| VAL_TABLE_, BO_TX_BU_, SIG_GROUP_, EV_ | Strict error; permissive text preservation + warning |
| SIG_VALTYPE_, SG_MUL_VAL_, SIG_TYPE_REF_ | Always rejected as codec-critical extensions |

Physical = raw × factor + offset. Encoding rounds nearest, ties away from zero,
and rejects range violations by default. Clamp is explicit. Raw mode bypasses
physical range checks. `[0|0]` is a literal zero-only physical range in this
implementation. Inputs beyond Double's exact integer precision require raw mode.
Multiplexing uses the selector's raw value. Unknown selectors produce a warning
with only always-active signals. Missing/inactive/duplicate assignments fail.

Frame length must exactly match message byte length. CAN FD-sized means a payload
greater than eight bytes; transport DLC conversion, BRS, CRC and hardware IO are
not implemented. Extended DBC IDs use bit 31; reserved bits 29/30 are rejected.
The writer is semantic, not formatting-lossless. Preserved extensions have no
codec semantics. Unknown multiline extensions are retained per line.

203 MoonBit tests, 1536 additional deterministic raw round-trips, 41 cantools
vectors and 15 native CLI smoke cases were executed. No coverage claim is made.
See [TESTING](docs/TESTING.md), [COMPATIBILITY](docs/COMPATIBILITY.md),
[BENCHMARKS](docs/BENCHMARKS.md) and [BIT_NUMBERING](docs/BIT_NUMBERING.md).
GitHub CI results are reported only after an actual remote run.

CLI IO reads an entire file before parsing applies its input budget; callers must
bound their file source/reader where this matters. Native/JS errors use stderr;
Wasm errors use stdout. Future work includes extended mux trees, broader independent
interop fixtures and bounded streaming IO. See CONTRIBUTING.md, SECURITY.md,
docs/REFERENCES.md and LICENSE.

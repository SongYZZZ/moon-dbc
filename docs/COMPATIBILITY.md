# Interoperability evidence

Executed on 2026-10-05, Windows 11, native release MoonDBC and cantools **44.1.0**.
Run: `python scripts/interop.py` after installing cantools into the ignored `.oracle`
directory or a separate Python environment. Python is a test oracle only; it is
not a runtime dependency of the library, native binary or Mooncakes module.

**37/37 vectors passed**: exact raw decoded values, selected signal names, physical
values (relative tolerance 1e-12 / absolute 1e-9), and raw encoded payloads agree.
The checked-in `interop-results.json` contains actual input bytes and both results.

| Fixture | Checks |
|---|---|
| basic.dbc | Intel, scaling, enum metadata, zero and upper raw range |
| motorola.dbc | unaligned 5-bit sawtooth, signed 12-bit, negative scaling offset |
| multiplex.dbc | raw selector 0/1/2, active branches and common signal |
| canfd.dbc | 64-byte data, final byte, extended-ID flag, exact unsigned 64-bit |
| motorola.dbc, 25 oracle-created vectors | raw 0/1/15/16/31 × signed -2048/-1/0/1/2047 |

Cantools uses its default signal sorting. Disabling sorting caused its CAN FD
fixture unpacker to report `Short data` for the reverse-declared little-endian
signals; the original fixture was retained and tested using the tool's default
ordering. Explicit raw encoding bypasses physical limits in MoonDBC, so the
equivalent cantools call uses `scaling=False, strict=False`. This preserves the
out-of-range decode vector rather than deleting it to obtain passing results.

This is evidence for these fixtures and integer semantics, not exhaustive DBC
compatibility. Unknown selector handling is tested in MoonBit; cantools rejects
selectors with no defined branch, while MoonDBC emits a warning and the always-active
signals. Extended multiplexing and floating-point signal encodings are unsupported.

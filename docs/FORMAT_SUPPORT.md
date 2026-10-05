# Format support in 0.1.0

This table is an implementation contract, not a claim of an official complete DBC standard.

| Statement | Parse / write / behavior |
|---|---|
| VERSION | Quoted version string, including empty |
| NS_ | Declaration identifiers; ends at BS_; declarations do not enable extensions |
| BS_ | Empty `BS_:` only; timing syntax rejected |
| BU_ | ASCII identifier node declarations |
| BO_ | Checked DBC ID, name, byte length 0..64, transmitter |
| SG_ | Required core layout/scaling/range/unit syntax; optional comma-separated receivers |
| CM_ | Quoted database/node/message/signal comments, UTF-8, multiline and escapes |
| VAL_ | Raw Int64 / quoted labels; forward references attached after parsing |
| BA_DEF_ | Four scopes, INT/HEX/FLOAT bounds, STRING, ENUM label lists |
| BA_DEF_DEF_ | Typed defaults; ENUM defaults accept an index or declared label |
| BA_ | Explicit object assignment, checked against schema |
| VAL_TABLE_ | No structured value-table interpretation |
| BO_TX_BU_ | No multiple-transmitter interpretation |
| SIG_GROUP_ | No signal-group interpretation |
| EV_ | No environment-variable interpretation |
| SIG_VALTYPE_ | No IEEE float signal interpretation; always rejected |
| SG_MUL_VAL_ | No extended mux; always rejected |
| SIG_TYPE_REF_ | No referenced signal-type codec; always rejected |

Noncritical unsupported text is rejected in Strict and preserved with Warning in
Permissive. Preservation is per physical statement line or terminating semicolon,
not an assertion that the extension grammar was understood. The writer appends
preserved fragments in order. Critical codec extensions are never preserved for use.

Identifiers use ASCII letters/underscore followed by letters/digits/underscore.
Default max length is 128. Core numeric parsing accepts decimal, 0x hexadecimal,
scientific real literals; the checked MoonBit integer parser also accepts prefixed
octal/binary and underscores as compatibility forms. Output uses decimal integers.
Quoted escapes: backslash, quote, n, r, t; unknown escapes/control characters fail.

CAN IDs: raw DBC bit 31 denotes extended; lower 29 bits are arbitration ID; bits
29/30 are unsupported flags. Standard ID max 0x7FF; extended max 0x1FFFFFFF.
No PGN matching is performed. Signals are integer 1..64 bits. VAL_ keys do not span
unsigned values above Int64.max, although raw codec values do span UInt64.

CAN FD support means payload byte processing up to 64, including final-byte signals.
No transport DLC mapping is claimed. Ranges are literal, including `[0|0]`.

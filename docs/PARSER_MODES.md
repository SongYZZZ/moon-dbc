# Parser modes

`parse_dbc` uses Strict; `parse_dbc_with_options` takes ParseOptions/ParseLimits.
CLI file commands use Strict unless --permissive is supplied.

Both modes reject malformed core syntax, invalid/overflowing numeric literals,
unterminated strings, unknown escapes, invalid widths, out-of-payload layouts,
zero factor, reversed ranges, orphan signals and dangling VAL_ references.
Both reject codec-critical SG_MUL_VAL_, SIG_VALTYPE_ and SIG_TYPE_REF_.

Strict rejects unsupported statement keywords. Permissive preserves noncritical
statement text and attaches `parse.preserved` warnings. This does not make their
semantics available to the codec. Unknown multiline metadata is retained per line;
use Strict when semantic completeness is required. No mode silently accepts a
codec-critical extension or corrupt signal layout.

Parsing and semantic validation are separate. Duplicate definitions, unknown nodes,
attribute references/types and active signal overlaps are collected by
validate_database. CLI validates before encoding, decoding, normalization or diff.
inspect can report an invalid model; validate returns status 1 for semantic errors.

Default resource limits (UTF-16 code units for text lengths): file 16 Mi units,
line/token/attribute 65536 units, name 128, nodes/messages 10000,
signals per message 512, total signals 100000, tokens 2000000,
metadata records 100000. Limits are configurable. Caller-provided Strings are
already allocated; the CLI's official IO dependency reads a whole file before these
checks. Applications needing pre-allocation file limits should bound their reader.

# Design

The root package is the reusable API; cmd/main is the process boundary. Parser,
codec and analysis never call a hardware or filesystem API. CLI commands can be
executed against caller-supplied text for testing. Files are separated by concern
inside one package to keep internal helpers private and avoid circular packages.

## Semantic model

Database owns typed nodes, messages, signals, attributes and comments. FrameId
contains arbitration ID and frame kind; Message retains raw_dbc_id. RawValue uses
Int64 / UInt64 to retain exact values that Double cannot represent. Signal includes
byte order, signedness, scaling, range, receivers, mux and value descriptions.
The model can be constructed directly, and validate_database checks these inputs.
Public arrays are mutable: callers should validate after edits. CompiledMessage
defensively copies signal/enum/receiver arrays so later edits cannot corrupt cached
layout. Query methods return Option and preserve message context for signal search.

## Parser pipeline

```text
UTF-16 MoonBit String -> located Tokens -> private Parser cursor
 -> semantic records -> deferred VAL_ attachment -> Database
 -> validate_database -> diagnostics
```

Quoted tokens retain an explicit quoted flag. Numbers use checked current core
string parsers. Line/column and offsets refer to UTF-16 code units, not invented
UTF-8 byte locations. The tokenizer understands multiline/escaped strings. Parser
budgets check before appending bounded structures. Invalid numeric data, layout,
zero factor and reversed ranges fail in both modes. Semantic duplication, unknown
nodes and attribute issues remain inspectable through the validator.

## Bit codec

```text
frame -> validated cached payload coordinates -> bit extraction
 -> signed interpretation -> factor/offset -> physical / label / range findings
```

Intel traverses low-to-high payload coordinates, assigning increasing raw weights.
Motorola starts at its raw MSB, decreases payload coordinates inside a byte, then
jumps from bit 0 to next byte's bit 7. Width is 1..64, payload 0..64. Full-width
signed conversion is special-cased to avoid a 64-bit shift. A shared checked bit
writer updates only its field, preserving unrelated bits.

Basic mux permits one unsigned selector. Branches are active by raw equality.
Validation tracks per-bit owners and reports only pairs that can be active together.
The compiled encoder resolves the selector once and rejects inactive assignments.

## Errors and writer

DbcError wraps stable-code Diagnostic. Parser errors carry source locations;
validation adds object names; codec failures identify the failed condition.
Decoded range violations are warnings. Range Reject is the physical encoder default;
clamping is explicit and quantized results are checked again. Raw APIs preserve
exact integer semantics and intentionally bypass physical min/max.

Writer emits stable LF text in model insertion order, reconstructing quoted strings,
IDs and typed metadata. Real attribute values keep a decimal marker to retain type.
It validates the model before output; preserved permissive extensions are appended
verbatim. Formatting and original statement order are not losslessly preserved.
Diff compares ID-keyed messages and name-keyed signals, not source lines. It ignores
source spans and receiver/enum ordering, and includes global metadata signatures.

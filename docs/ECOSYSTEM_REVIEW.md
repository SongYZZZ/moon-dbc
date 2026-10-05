# Ecosystem review

Reviewed on 2026-10-05 (Asia/Shanghai). Keywords: MoonBit DBC, MoonBit CAN DBC,
MoonBit CAN database, MoonBit CAN parser, MoonBit CAN FD, moon-dbc, MoonDBC.

Sources checked: GitHub search, Mooncakes local registry index and indexed web
results, moonbit-community repositories, moonbitlang/awesome-moonbit, publicly
indexed October hackathon results. The October project list could not be
established as exhaustive; absence in search results is not proof of absence.

## Existing project

[curry3point/moonbit-dbc-toolkit](https://github.com/curry3point/moonbit-dbc-toolkit)
is published as curry3point/dbc-toolkit 0.1.1 (registry date 2026-08-24), Apache-2.0.
The reviewed repository has 20 commits. Its README documents a parser, validation,
Intel/Motorola 1–64-bit codecs, scaling, value labels, comparison, serialization,
statistics, batch processing and transformations. It is substantially more than
a parser. It explicitly rejects multiplexed signals; it works on in-memory
inputs without file IO or an end-user CLI. Common attributes are outside its
documented parsed subset. It documents CAN FD validation policy.

## Independent value required for MoonDBC

MoonDBC will implement basic multiplex activation and branch-aware overlap
validation, structured attributes and defaults, database/node comments, and a
file-based CLI offering inspect/validate/encode/decode/layout/diff. These are
concrete additions to the reviewed documented boundary, not a name change.
Both projects share unavoidable DBC concepts. No implementation source from the
existing project has been imported or copied. This review used its README,
public metadata and package index only. Do not claim to be the first DBC library.

## Other reviewed indexes

- https://mooncakes.io/ (local index contains curry3point/dbc-toolkit 0.1.0/0.1.1)
- https://github.com/moonbit-community
- https://github.com/moonbitlang/awesome-moonbit
- Search for public October 2026 MoonBit hackathon projects: no exhaustive list verified.

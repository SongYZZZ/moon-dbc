# References and provenance

Reviewed on 2026-10-05. DBC is a historical format with vendor extensions; these
sources describe publicly documented behavior rather than an invented full standard.

| Source | Purpose |
|---|---|
| https://kvaser.com/canlib-webhelp/group__kvadb__signals.htm | DBC sawtooth numbering and Motorola MSB start |
| https://www.csselectronics.com/pages/can-dbc-file-database-intro | Message/signal fields, scaling, bit-31 extended IDs |
| https://www.csselectronics.com/pages/can-fd-flexible-data-rate-intro | Public CAN FD payload/transport context |
| https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html | Current MoonBit project/package configuration |
| https://docs.moonbitlang.com/en/latest/language/fundamentals.html | Language/error handling context |
| Local toolchain D:/Moonbit/lib/core | Actual current String, numeric, bit, env, UTF-8 and bench APIs |
| https://github.com/hustcer/setup-moonbit | Verified Actions setup usage; v1.22 |
| https://cantools.readthedocs.io/en/latest/ | Oracle API/codec behavior |

## Open-source projects

- **cantools**, https://github.com/cantools/cantools, MIT. Purpose: separate Python
  test oracle only, version 44.1.0. No source incorporated into MoonDBC.
- **moonbitlang/core**, https://github.com/moonbitlang/core, Apache-2.0. Official
  standard library and current API source/reference, provided by the toolchain.
- **moonbitlang/x**, https://github.com/moonbitlang/x, Apache-2.0. Official dependency
  pinned to 0.5.1 for CLI filesystem/process support, not DBC logic.
- **curry3point/moonbit-dbc-toolkit**, https://github.com/curry3point/moonbit-dbc-toolkit,
  Apache-2.0. Ecosystem review of public README/metadata only; no implementation
  source copied, imported, vendored or used as a runtime dependency.

MoonDBC is independently implemented from documented behavior and public format
descriptions. Source code from third-party DBC libraries is not copied into this
project. All DBC fixtures and manual bit vectors are original, Apache-2.0.
The project was developed with AI assistance; the maintainer must be able to explain
the public model, parser budgets, sawtooth algorithm, sign extension and mux activation.
Generated `.mbti` interfaces and build output are excluded from source-size claims.

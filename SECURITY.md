# Security

Treat DBC input and in-memory models as untrusted. Parser limits bound token/model
construction. Invalid numeric literals, lengths and coordinates return DbcError;
public codec operations validate before accessing payload positions or shifting.
Applications should validate modified models and bound IO before supplying text.
The CLI dependency currently reads an entire file before parser budgets apply.

Report a reproducible crash, resource exhaustion or incorrect frame interpretation
privately to the repository maintainer through GitHub's private vulnerability
reporting when available. If that feature is unavailable, open an issue asking for
a private contact without posting confidential input. Never include proprietary
vehicle databases, credentials or personally identifying traces.

Include MoonBit version, backend, smallest distributable reproducer and expected
vs actual behavior. This toolkit provides data conversion and validation; it does
not perform safety-certified control or actual bus transmission.

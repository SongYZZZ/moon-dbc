# Measured benchmarks

Executed 2026-10-05 using `moon bench --target native --release`.
Rerun after the acceptance-review fixes, with `MOON_HOME=D:\Moonbit`.

- moon 0.1.20260819 (fc2a4ee), moonc v0.10.9+6e6c44045, moonrun 0.1.20260819.
- Native release backend; Intel Core i7-14650HX.
- Windows 11 Home, version 10.0.22621.
- Official `moonbitlang/core/bench` runner; 5 samples, adaptive batch size.
- Measurements include normal allocations; compiled frame layout construction is
  outside timed codec loops. Frame loops perform 100,000 operations per measurement.

| Workload | Mean | Standard deviation |
|---|---:|---:|
| Parse small database (2 signals) | 22.12 µs | 2.23 µs |
| Parse 100 messages / 800 signals | 4.10 ms | 84.92 µs |
| Parse 1000 messages / 8000 signals | 48.92 ms | 4.66 ms |
| Parse 1000 messages / 10000 signals | 62.62 ms | 3.50 ms |
| Decode 100k frames, cached layout | 121.55 ms | 2.80 ms |
| Encode 100k frames, cached layout | 155.03 ms | 7.63 ms |
| Semantic diff, 100 messages | 2.06 ms | 108.33 µs |

Parser numbers measure parsing and structural layout checks, not a subsequent full
database validation pass. Large sources are built once outside timing. Checksums
are retained with `Bench::keep` to avoid dead-code elimination. No comparison to
other tools is claimed. Results depend on backend, CPU, scheduling and allocation.
See `benchmark-native.txt` for the actual runner output.

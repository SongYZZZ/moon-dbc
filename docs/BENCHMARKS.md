# Measured benchmarks

Executed 2026-10-05 using `moon bench --target native --release`.

- moon 0.1.20260819 (fc2a4ee), moonc v0.10.9+6e6c44045, moonrun 0.1.20260819.
- Native release backend; Intel Core i7-14650HX.
- Windows 11 Home, version 10.0.22621.
- Official `moonbitlang/core/bench` runner; 5 samples, adaptive batch size.
- Measurements include normal allocations; compiled frame layout construction is
  outside timed codec loops. Frame loops perform 100,000 operations per measurement.

| Workload | Mean | Standard deviation |
|---|---:|---:|
| Parse small database (2 signals) | 20.77 µs | 1.05 µs |
| Parse 100 messages / 800 signals | 4.66 ms | 367.51 µs |
| Parse 1000 messages / 8000 signals | 50.51 ms | 4.00 ms |
| Parse 1000 messages / 10000 signals | 59.37 ms | 2.03 ms |
| Decode 100k frames, cached layout | 33.39 ms | 703.62 µs |
| Encode 100k frames, cached layout | 61.17 ms | 7.51 ms |
| Semantic diff, 100 messages | 1.93 ms | 67.09 µs |

Parser numbers measure parsing and structural layout checks, not a subsequent full
database validation pass. Large sources are built once outside timing. Checksums
are retained with `Bench::keep` to avoid dead-code elimination. No comparison to
other tools is claimed. Results depend on backend, CPU, scheduling and allocation.
See `benchmark-native.txt` for the actual runner output.

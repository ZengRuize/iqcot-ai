# R049R PR-ECB Release-Between-Point Audit
Date: 2026-06-25

## Baseline check

Baseline: `PASS`.

## Windowed pair deltas
| Offset | Window | Peak improvement | Undershoot improvement | one-shot us |
|---:|---|---:|---:|---:|
| `0.050` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `1.6700` |
| `0.050` | `recovery_peak` | `0.0000 mV` | `0.0000 mV` | `1.6700` |
| `0.050` | `late_settling` | `0.0000 mV` | `0.0000 mV` | `1.6700` |
| `0.105` | `early_local_peak` | `0.0000 mV` | `-0.2929 mV` | `1.6550` |
| `0.105` | `recovery_peak` | `0.1244 mV` | `-0.7873 mV` | `1.6550` |
| `0.105` | `late_settling` | `0.0354 mV` | `0.0492 mV` | `1.6550` |

## Decision
```text
MODEL_REVISED
```

## Interpretation
`1.615us` is the first between-point after R049P's `1.600us` midpoint and R049Q's `1.630us` later point. It should be interpreted only relative to the R049O/R049P/R049Q/R049N timing bracket: `1.250-1.450us` was transparent, `1.600us` was offset-selective, `1.630us` had stronger undershoot penalty, and `1.685us` was active but too hard.

# R049Q PR-ECB Release-Later-Point Audit
Date: 2026-06-25

## Baseline check

Baseline: `PASS`.

## Windowed pair deltas
| Offset | Window | Peak improvement | Undershoot improvement | one-shot us |
|---:|---|---:|---:|---:|
| `0.050` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `1.6700` |
| `0.050` | `recovery_peak` | `0.0000 mV` | `0.0000 mV` | `1.6700` |
| `0.050` | `late_settling` | `0.0000 mV` | `0.0000 mV` | `1.6700` |
| `0.105` | `early_local_peak` | `0.0000 mV` | `-0.4331 mV` | `1.6950` |
| `0.105` | `recovery_peak` | `0.1365 mV` | `-1.1109 mV` | `1.6950` |
| `0.105` | `late_settling` | `-0.0666 mV` | `0.0596 mV` | `1.6950` |

## Decision
```text
MODEL_REVISED
```

## Interpretation
`1.630us` is the first slightly later point after R049P's `1.600us` midpoint. It should be interpreted only relative to the R049O/R049P/R049N timing bracket: `1.250-1.450us` was transparent, `1.600us` was offset-selective, and `1.685us` was active but too hard.

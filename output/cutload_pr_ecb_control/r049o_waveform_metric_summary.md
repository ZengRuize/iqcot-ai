# R049O PR-ECB Release-Timing Micro-Audit
Date: 2026-06-25

## Baseline check

Baseline: `PASS`.

## Windowed pair deltas
| Offset | A2 delay | Window | Peak improvement | Undershoot improvement | one-shot us |
|---:|---|---|---:|---:|---:|
| `0.050` | `A2_1p250` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `1.3100` |
| `0.050` | `A2_1p250` | `recovery_peak` | `0.0000 mV` | `0.0000 mV` | `1.3100` |
| `0.050` | `A2_1p250` | `late_settling` | `0.0000 mV` | `0.0000 mV` | `1.3100` |
| `0.050` | `A2_1p450` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `1.5100` |
| `0.050` | `A2_1p450` | `recovery_peak` | `0.0000 mV` | `0.0000 mV` | `1.5100` |
| `0.050` | `A2_1p450` | `late_settling` | `0.0000 mV` | `0.0000 mV` | `1.5100` |
| `0.105` | `A2_1p250` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `1.2950` |
| `0.105` | `A2_1p250` | `recovery_peak` | `0.0000 mV` | `0.0000 mV` | `1.2950` |
| `0.105` | `A2_1p250` | `late_settling` | `0.0000 mV` | `0.0000 mV` | `1.2950` |
| `0.105` | `A2_1p450` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `1.4950` |
| `0.105` | `A2_1p450` | `recovery_peak` | `0.0000 mV` | `0.0000 mV` | `1.4950` |
| `0.105` | `A2_1p450` | `late_settling` | `0.0000 mV` | `0.0000 mV` | `1.4950` |

## Decision
```text
CLAIM_DOWNGRADED
```

## Interpretation
Earlier releases at `1.250us` and `1.450us` fire successfully, but their waveforms are effectively indistinguishable from A0 in the tested windows. They reduce the R049N undershoot penalty by removing most of the inhibit effect, but they also remove the recovery-peak improvement. The useful design space is therefore between `1.450us` and `1.685us`, or requires a soft instead of binary release.

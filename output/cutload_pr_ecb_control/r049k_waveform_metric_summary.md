# R049K PR-ECB Short Soft-Reentry Proxy Waveform Metric Audit
Date: 2026-06-25
## Scope
R049K audits one new derived-Simulink request-path action chunk: `40A -> 20A` at `0.05us` and `0.105us`, A0 same-model no-inhibit versus A2 shortened soft-reentry proxy.  Ton truncation is disabled in both A0 and A2.

## Windowed comparison
| Offset | Window | Peak improvement | A2-A0 max | Undershoot change | A0 min | A2 min | Final error change |
|---:|---|---:|---:|---:|---:|---:|---:|
| `0.050` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `-0.2917 mV` | `0.0704 mV` | `-0.2213 mV` | `-0.0026 mV` |
| `0.050` | `late_settling` | `-0.1318 mV` | `0.1318 mV` | `-0.0261 mV` | `-0.8909 mV` | `-0.9170 mV` | `-0.0026 mV` |
| `0.050` | `recovery_peak` | `0.1796 mV` | `-0.1796 mV` | `-0.6388 mV` | `-0.4026 mV` | `-1.0414 mV` | `-0.0026 mV` |
| `0.105` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `-0.6663 mV` | `0.0950 mV` | `-0.5713 mV` | `0.0037 mV` |
| `0.105` | `late_settling` | `-0.0223 mV` | `0.0223 mV` | `0.0547 mV` | `-0.8991 mV` | `-0.8444 mV` | `0.0037 mV` |
| `0.105` | `recovery_peak` | `0.1954 mV` | `-0.1954 mV` | `-1.6588 mV` | `-0.0030 mV` | `-1.6619 mV` | `0.0037 mV` |

## Decision
```text
MODEL_REVISED
```

## Diagnosis
The request-path action satisfies the no-current-pulse-truncation intent, but the shortened `0.07-1.76us` proxy still has an undershoot cost: it creates an undershoot penalty even while reducing positive recovery peaks.  The state machine should either shorten/phase-select the reentry gate further or move to controlled reentry with softer request restoration.

## Claim boundary
R049K is derived-Simulink switching evidence only.  It is not hardware/HIL validation, not complete PR-ECB control, and not global calibration.

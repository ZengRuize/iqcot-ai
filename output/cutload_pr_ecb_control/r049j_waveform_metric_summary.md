# R049J PR-ECB Deferred Post-Active Inhibit Waveform Metric Audit
Date: 2026-06-25
## Scope
R049J audits one new derived-Simulink request-path action chunk: `40A -> 20A` at `0.05us` and `0.105us`, A0 same-model no-inhibit versus A2 deferred post-active pulse inhibit.  Ton truncation is disabled in both A0 and A2.

## Windowed comparison
| Offset | Window | Peak improvement | A2-A0 max | Undershoot change | A0 min | A2 min | Final error change |
|---:|---|---:|---:|---:|---:|---:|---:|
| `0.050` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `-1.2128 mV` | `0.0704 mV` | `-1.1424 mV` | `0.0034 mV` |
| `0.050` | `late_settling` | `0.0903 mV` | `-0.0903 mV` | `0.0532 mV` | `-0.8909 mV` | `-0.8378 mV` | `0.0034 mV` |
| `0.050` | `recovery_peak` | `0.6262 mV` | `-0.6262 mV` | `-2.9901 mV` | `-0.4026 mV` | `-3.3927 mV` | `0.0034 mV` |
| `0.105` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `-1.6300 mV` | `0.0950 mV` | `-1.5350 mV` | `-0.0073 mV` |
| `0.105` | `late_settling` | `0.2034 mV` | `-0.2034 mV` | `-0.0067 mV` | `-0.8991 mV` | `-0.9058 mV` | `-0.0073 mV` |
| `0.105` | `recovery_peak` | `0.5813 mV` | `-0.5813 mV` | `-4.1571 mV` | `-0.0030 mV` | `-4.1602 mV` | `-0.0073 mV` |

## Decision
```text
MODEL_REVISED
```

## Diagnosis
The request-path action satisfies the no-current-pulse-truncation intent, but the `0.07-2.00us` inhibit window is too aggressive for reentry: it creates an undershoot penalty even while reducing positive recovery peaks.  The state machine should either shorten/phase-select the post-active inhibit or move to controlled reentry with softer request restoration.

## Claim boundary
R049J is derived-Simulink switching evidence only.  It is not hardware/HIL validation, not complete PR-ECB control, and not global calibration.

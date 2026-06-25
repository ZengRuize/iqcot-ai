# R049N PR-ECB Independent-Clock Reentry Waveform Metric Audit
Date: 2026-06-25

## Baseline check vs R049K / R049L repair

Baseline matches the repaired R049K-compatible gate within tolerance.

## Windowed comparison
| Offset | Window | Peak improvement | A2-A0 max | Undershoot change | A0 min | A2 min | Final error change |
|---:|---|---:|---:|---:|---:|---:|---:|
| `0.050` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `-0.2559 mV` | `0.0704 mV` | `-0.1855 mV` | `0.0097 mV` |
| `0.050` | `recovery_peak` | `0.1127 mV` | `-0.1127 mV` | `-0.5597 mV` | `-0.4026 mV` | `-0.9623 mV` | `0.0097 mV` |
| `0.050` | `late_settling` | `-0.0696 mV` | `0.0696 mV` | `-0.0084 mV` | `-0.8909 mV` | `-0.8994 mV` | `0.0097 mV` |
| `0.105` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `-0.5775 mV` | `0.0950 mV` | `-0.4826 mV` | `-0.0003 mV` |
| `0.105` | `recovery_peak` | `0.1205 mV` | `-0.1205 mV` | `-1.4429 mV` | `-0.0030 mV` | `-1.4460 mV` | `-0.0003 mV` |
| `0.105` | `late_settling` | `-0.0148 mV` | `0.0148 mV` | `-0.0303 mV` | `-0.8991 mV` | `-0.9294 mV` | `-0.0003 mV` |

## Independent-clock one-shot timing
| Offset | A2 first inhibit us | A2 release_clock us | A2 one-shot done us | A2 raw inhibit us | A2 effective inhibit us |
|---:|---:|---:|---:|---:|---:|
| `0.050` | `0.0700` | `1.6860` | `1.7500` | `1.6900` | `1.6800` |
| `0.105` | `0.0710` | `1.6850` | `1.7350` | `1.6900` | `1.6640` |

## Decision
```text
MODEL_REVISED
```

## Claim boundary
R049N is a derived-Simulink switching chunk only. It does not validate hardware/HIL behavior, does not complete PR-ECB, and does not make the independent phase-clock a final controller; it only tests whether an upstream predicted-slot release can fire and how it changes the R049H early/recovery/late waveform windows.

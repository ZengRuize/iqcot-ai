# R049L Repair PR-ECB Phase-Boundary Controlled-Reentry Waveform Metric Audit
Date: 2026-06-25
## Baseline check vs R049K

Baseline matches R049K within tolerance.

**ONE-SHOT RELEASE MISSING:**
- offset 0.050: missing A2 one-shot release time
- offset 0.105: missing A2 one-shot release time

Status: IMPLEMENTATION_ISSUE

## Scope
R049L repair audits one derived-Simulink phase-boundary controlled-reentry chunk: `40A -> 20A` at `0.05us` and `0.105us`, A0 same-model no-inhibit versus A2 qh1-rising-edge one-shot controlled-reentry proxy.  Ton truncation is disabled in both A0 and A2.

## Windowed comparison
| Offset | Window | Peak improvement | A2-A0 max | Undershoot change | A0 min | A2 min | Final error change |
|---:|---|---:|---:|---:|---:|---:|---:|
| `0.050` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `-0.2917 mV` | `0.0704 mV` | `-0.2213 mV` | `-0.0026 mV` |
| `0.050` | `recovery_peak` | `0.1796 mV` | `-0.1796 mV` | `-0.6388 mV` | `-0.4026 mV` | `-1.0414 mV` | `-0.0026 mV` |
| `0.050` | `late_settling` | `-0.1318 mV` | `0.1318 mV` | `-0.0261 mV` | `-0.8909 mV` | `-0.9170 mV` | `-0.0026 mV` |
| `0.105` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `-0.6663 mV` | `0.0950 mV` | `-0.5713 mV` | `0.0037 mV` |
| `0.105` | `recovery_peak` | `0.1954 mV` | `-0.1954 mV` | `-1.6588 mV` | `-0.0030 mV` | `-1.6619 mV` | `0.0037 mV` |
| `0.105` | `late_settling` | `-0.0223 mV` | `0.0223 mV` | `0.0547 mV` | `-0.8991 mV` | `-0.8444 mV` | `0.0037 mV` |

## One-shot timing
| Offset | A2 first inhibit us | A2 one-shot done us | A2 inhibit_raw us | A2 effective inhibit us |
|---:|---:|---:|---:|---:|
| `0.050` | `0.0700` | `nan` | `1.6900` | `1.6900` |
| `0.105` | `0.0710` | `nan` | `1.6900` | `1.6900` |

## Decision
```text
IMPLEMENTATION_ISSUE
```

## Diagnosis
The A0 baseline matches R049K, but the intended phase-boundary one-shot release never fired in A2.  Using qh1 rising as the release trigger creates a circular dependency because the request gate suppresses the pulse that would produce the qh1 edge.  Treat this as an implementation/wiring issue, not as evidence against controlled reentry.

## Claim boundary
R049L repair is derived-Simulink switching evidence only.

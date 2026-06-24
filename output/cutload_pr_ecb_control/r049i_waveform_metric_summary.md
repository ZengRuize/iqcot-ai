# R049I PR-ECB Gentle Ton-Trim Waveform Metric Audit
Date: 2026-06-24
## Scope
R049I audits one new derived-Simulink action chunk: `40A -> 20A` at `0.05us` and `0.105us`, A0 same-model no-trim versus A2 gentle phase-selective Ton trim with `Tton_trunc_min=120ns`.
It uses the R049H three-window metric gate:
- `0-2 us`: early local peak / immediate switching interaction.
- `2-12 us`: recovery peak.
- `12-80 us`: late settling and undershoot.

## Floor selection note
R049G baseline traces show `Ton_cmd4=196.5ns`; in the `0.05us` active-HS row, phase 4 has about `52ns` remaining at the load step, so the pulse has already been on for about `144.5ns`.  R049I selects `120ns`, the gentlest end of the suggested `80-120ns` first-candidate band, while explicitly treating the already-elapsed on-time as a risk: the action may still terminate the current active-HS pulse quickly.

## A2 versus A0 windowed comparison
| Offset | Window | Peak improvement | A2-A0 max | A0 max time | A2 max time | Undershoot change | Final error change |
|---:|---|---:|---:|---:|---:|---:|---:|
| `0.050` | `early_local_peak` | `-0.2902 mV` | `0.2902 mV` | `0.484 us` | `0.898 us` | `0.4725 mV` | `0.0046 mV` |
| `0.050` | `late_settling` | `-0.0866 mV` | `0.0866 mV` | `12.716 us` | `12.042 us` | `0.0348 mV` | `0.0046 mV` |
| `0.050` | `recovery_peak` | `-0.0476 mV` | `0.0476 mV` | `9.454 us` | `7.602 us` | `-0.0201 mV` | `0.0046 mV` |
| `0.105` | `early_local_peak` | `0.0000 mV` | `0.0000 mV` | `0.429 us` | `0.429 us` | `0.0000 mV` | `0.0000 mV` |
| `0.105` | `late_settling` | `0.0000 mV` | `0.0000 mV` | `12.209 us` | `12.209 us` | `0.0000 mV` | `0.0000 mV` |
| `0.105` | `recovery_peak` | `0.0000 mV` | `0.0000 mV` | `8.389 us` | `8.389 us` | `0.0000 mV` | `0.0000 mV` |

## Decision
```text
MODEL_REVISED
```

## Diagnosis
The gentle `120ns` phase-selective Ton trim still fails the R049H early-local-peak acceptance gate: `A2-A0=0.2902mV` in `0-2us`, with recovery-window `A2-A0=0.0476mV`. Per the R049I stopping rule, do not continue scanning Ton floors; the next action should move to deferred post-active pulse inhibit or controlled reentry.

## Claim boundary
R049I is derived-Simulink switching evidence only.  It is not hardware/HIL validation, not complete PR-ECB control, not global calibration, and not a universal additive `E_HS,rem` law.

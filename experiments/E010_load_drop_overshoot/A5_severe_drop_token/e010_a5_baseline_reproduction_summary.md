# E010-A5 Baseline Reproduction Summary

Date: 2026-06-30

## Result

`MODEL_CONFIRMED`

Baseline severe-drop audit passed. A5-C0 and A5-C4 ran with complete core logging; A5-C4 reproduced the known no-harm but non-improving A4 boundary for 40A -> 1A. No A5 improvement claim is made.

## Reproduction Table

| Variant | Success | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | REQ | Accepted | Dropped | Phase err | Final err mV | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A5-C0 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 149 | 149 | 0 | 0 | 2.97793 | baseline_reproduction_metrics_computable |
| A5-C4 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 149 | 149 | 0 | 0 | 2.97793 | previous_A4_no_harm_boundary_reproduced_pending_pairwise_check |

## A5-C4 Boundary

A5-C4 reproduces the known severe-drop boundary: A4 is no-harm but non-improving for `40A -> 1A`. Delta peak overshoot is `0 mV`; delta 2-12 us recovery peak is `0 mV`. This confirms the need for A5 but does not validate A5.

## Evidence Files

- Metrics: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_baseline_metrics.csv`
- Signal availability: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_baseline_signal_availability.csv`
- Scheduler audit: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_baseline_scheduler_audit.csv`

## Claim Boundary

Allowed: the A5 severe-drop validation infrastructure is ready only if this audit is `MODEL_CONFIRMED`. Forbidden: claiming A5 improves overshoot/recovery, A5 robustness, active-phase mixing, PIS-IEK first-peak prediction, or hardware/HIL/board/silicon validation.

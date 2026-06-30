# E010-A5-T4-R1 Candidate Comparison

Date: 2026-06-30

## Scope

This R1 comparison carries forward `R1-C0`, `R1-C4`, and `R1-T4proxy`, then runs only `R1-T4a`, `R1-T4b`, and `R1-T4c` for the fixed external `40A -> 1A` load-current drop. It does not enable active Lambda, active-phase add/shed, DCR mismatch, current-sense mismatch, or a broader load-step grid.

The baseline references are the already confirmed A5-C0/A5-C4 audit values: peak overshoot `4.06085 mV`, recovery peak 2-12 us `3.61172 mV`, and recovery peak 12-40 us `3.59863 mV`. The carried-forward T4proxy keeps the previous partial recovery improvement but fails burst guard with `5 / 2` pulses.

## Candidate Settings

- `R1-T4a`: explicit burst limiter and conservative inter-pulse spacing in the IQCOT request-enable path.
- `R1-T4b`: T4a plus area-int reentry clamp while burst limiting is active.
- `R1-T4c`: T4b plus conservative recovery Ton ramp.

## Metrics Snapshot

| Variant | Success | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | REQ | Accepted | Dropped | Phase err | Final err mV | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R1-C0 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 149 | 149 | 0 | 0 | 2.97793 | carry_forward_reference |
| R1-C4 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 149 | 149 | 0 | 0 | 2.97793 | carry_forward_reference |
| R1-T4proxy | 1 | 4.06085 | 0.697797 | 3.55696 | 3.5337 | 149 | 149 | 0 | 0 | 2.96743 | carry_forward_reference |
| R1-T4a | 1 | 0 | 971.618 | 0 | 0 | 187 | 187 | 0 | 0 | -919.625 | positive_peak_suppressed_by_undershoot_guard_fail |
| R1-T4b | 1 | 0 | 971.618 | 0 | 0 | 187 | 187 | 0 | 0 | -919.625 | positive_peak_suppressed_by_undershoot_guard_fail |
| R1-T4c | 1 | 0 | 971.618 | 0 | 0 | 187 | 187 | 0 | 0 | -919.625 | positive_peak_suppressed_by_undershoot_guard_fail |

## Guard Summary

| Variant | Formal positive metric lower | Guard pass | Dropped REQ | Phase err | Current limit | Undershoot fail | Burst count/limit | Late settling fail | Classification |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R1-C0 | 0 | 1 | 0 | 0 | 0 | 0 | NaN / NaN | 0 | REFERENCE |
| R1-C4 | 0 | 1 | 0 | 0 | 0 | 0 | NaN / NaN | 0 | REFERENCE |
| R1-T4proxy | 1 | 0 | 0 | 0 | 0 | 0 | 5 / 2 | 0 | MODEL_REVISED |
| R1-T4a | 1 | 0 | 0 | 0 | 0 | 1 | 5 / 2 | 0 | MODEL_REVISED |
| R1-T4b | 1 | 0 | 0 | 0 | 0 | 1 | 5 / 2 | 0 | MODEL_REVISED |
| R1-T4c | 1 | 0 | 0 | 0 | 0 | 1 | 5 / 2 | 0 | MODEL_REVISED |

## Files

- Metrics CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/e010_a5_t4_r1_metrics.csv`
- Signal availability CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/e010_a5_t4_r1_signal_availability.csv`
- Scheduler audit CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/e010_a5_t4_r1_scheduler_audit.csv`

## Classification

`MODEL_REVISED`

R1 preserves the earlier T4proxy partial recovery reference, but the new burst-limited candidates fail the guard set. R1-T4a/b/c suppress positive peaks by driving severe undershoot/final-error collapse and still leave burst count above the limit.

R1-T4a/b/c zero positive overshoot/recovery peaks are not accepted as useful improvement. The measured `peak_undershoot_mV = 971.618`, `final_Vout_error_mV = -919.625`, and burst count `5 / 2` show that count-based burst limiting did not close the original reentry guard failure.

Audit note: the phase-order guard in `e010_a5_t4_r1_metrics.csv` is computed from the accepted-REQ event sequence. The optional sampled model signal `phase_order_error` is retained in the scheduler audit as `model_phase_order_error_sample` and is not used as the pass/fail event-sequence guard because it can pulse at sampled edge times.

Best partial candidate before guard revision: `R1-T4proxy`.

Simulink-only evidence remains local model evidence only; no hardware, HIL, board, or silicon claim is made.

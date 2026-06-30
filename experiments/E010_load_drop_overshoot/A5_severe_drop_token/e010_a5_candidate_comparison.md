# E010-A5 Candidate Comparison

Date: 2026-06-30

## Scope

This comparison ran only `A5-T1`, `A5-T2`, `A5-T3`, and `A5-T4` for the fixed external `40A -> 1A` load-current drop. It did not enable active Lambda, active-phase add/shed, DCR mismatch, current-sense mismatch, or a broader load-step grid.

The baseline references are the already confirmed A5-C0/A5-C4 audit values: peak overshoot `4.06085 mV`, recovery peak 2-12 us `3.61172 mV`, and recovery peak 12-40 us `3.59863 mV`.

## Candidate Settings

- `A5-T1`: Ton truncation only, `Tton_trunc_min=60 ns`, `Tton_trunc_window=2 us`.
- `A5-T2`: T1 plus bounded inhibit window, `inhibit_time=1.8 us`, release guard `Vout <= Vref + 1.0 mV`.
- `A5-T3`: T2 retuned to `3.0 us`, plus conservative area hold/reset projection through the IQCOT request-enable path.
- `A5-T4`: severe-drop token proxy using the same conservative T3 implemented settings, reentry guard, and burst-limit bookkeeping. It does not yet implement a passing fallback/burst limiter.

## Metrics Snapshot

| Variant | Success | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | REQ | Accepted | Dropped | Phase err | Final err mV | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A5-T1 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 149 | 149 | 0 | 0 | 2.97793 | candidate_no_safe_improvement |
| A5-T2 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 149 | 149 | 0 | 0 | 2.97793 | candidate_no_safe_improvement |
| A5-T3 | 1 | 4.06085 | 0.697797 | 3.55696 | 3.53370 | 149 | 149 | 0 | 0 | 2.96743 | candidate_improves_but_guard_fails |
| A5-T4 | 1 | 4.06085 | 0.697797 | 3.55696 | 3.53370 | 149 | 149 | 0 | 0 | 2.96743 | candidate_improves_but_guard_fails |

## Guard Summary

| Variant | Improves C0/C4 | Guard pass | Dropped REQ | Phase err | Current limit | Undershoot fail | Burst count/limit | Late settling fail | Classification |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A5-T1 | 0 | 1 | 0 | 0 | 0 | 0 | 4 / Inf | 0 | CLAIM_DOWNGRADED |
| A5-T2 | 0 | 0 | 0 | 0 | 0 | 0 | 4 / 1 | 0 | CLAIM_DOWNGRADED |
| A5-T3 | 1 | 0 | 0 | 0 | 0 | 0 | 5 / 2 | 0 | MODEL_REVISED |
| A5-T4 | 1 | 0 | 0 | 0 | 0 | 0 | 5 / 2 | 0 | MODEL_REVISED |

## Interpretation

`A5-T1` and `A5-T2` reproduce the A5-C0/A5-C4 boundary: the first useful accepted REQ occurs after the `2 us` Ton truncation window, so the peak and recovery metrics remain unchanged.

`A5-T3` and `A5-T4` reduce the recovery peaks (`2-12 us` by `0.054759 mV`, `12-40 us` by `0.06494 mV`) while keeping undershoot below the `2.0 mV` budget and preserving `REQ=149/149/0`. The accepted-REQ event sequence remains phase ordered, but the auxiliary sampled model diagnostic is retained separately as `model_phase_order_error_sample` in the scheduler audit because it can pulse at sampled edge times. T3/T4 both create `5` accepted pulses in the post-reentry burst window against the configured limit of `2`; therefore the guard set fails.

## Classification

`MODEL_REVISED`

Ton truncation and the short one-pulse inhibit are insufficient for the severe `40A -> 1A` branch. The area-hold/reentry projection has a measurable recovery benefit, but the controlled-reentry/burst limiter must be revised before any A5 severe-drop improvement claim is allowed. The present T4 result should be read as a state-machine proxy result, not as a complete full-token validation.

A later rerun after these results hit a MATLAB/SDI temporary DMR database-full error; that environment failure is not used as A5 evidence.

## Files

- Metrics CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_candidate_metrics.csv`
- Signal availability CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_candidate_signal_availability.csv`
- Scheduler audit CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_candidate_scheduler_audit.csv`

Simulink-only evidence remains local model evidence only; no hardware, HIL, board, or silicon claim is made.

# E010-A5 Baseline Reproduction And Logging Audit

Date: 2026-06-30

## Scope

This audit ran only `A5-C0` and `A5-C4` for the fixed external `40A -> 1A` load-current drop. It did not run A5-T1/T2/T3/T4, active Lambda, active-phase add/shed, DCR mismatch, or current-sense mismatch.

## Required Checks

1. Derived copies were created from `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`; the baseline `.slx` was not modified.
2. A5-C0 reproduction status: `passed`.
3. A5-C4 previous-A4 reproduction status: `passed`.
4. Vout peak/recovery metrics are computable: `yes`.
5. REQ_count, accepted_REQ_count, and dropped_REQ_count are computable: `yes`.
6. phase_order_error_rate is computable: `yes`.
7. area_int_i is logged and finite: `yes`.
8. active_HS_phase is available through a passive QH observer.
9. first_reentry_time_us and burst_pulse_count_after_reentry are represented without fabrication: reentry is `not_applicable` for C0/C4, burst count is logged as zero-state baseline.
10. Missing/NaN/inferred metrics: reentry-specific fields are NaN because no A5 controlled reentry exists in C0/C4; no hard-pass metric is fabricated.

## Metrics Snapshot

| Variant | Success | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | REQ | Accepted | Dropped | Phase err | Final err mV | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A5-C0 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 149 | 149 | 0 | 0 | 2.97793 | baseline_reproduction_metrics_computable |
| A5-C4 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 149 | 149 | 0 | 0 | 2.97793 | previous_A4_no_harm_boundary_reproduced_pending_pairwise_check |

## Files

- Metrics CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_baseline_metrics.csv`
- Signal availability CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_baseline_signal_availability.csv`
- Scheduler audit CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_baseline_scheduler_audit.csv`

## Structural Check Note

`model_check` reports the same seven unconnected-block errors on the original baseline and on both derived A5-C0/A5-C4 models: `Add`, `Add1`, `Add2`, `Add3`, `Add4`, and the root `OnDelay` input/output. These are inherited baseline artifacts, not new A5 logging edits. The derived simulations completed successfully and the baseline `.slx` was not modified.

## Classification

`MODEL_CONFIRMED`

Baseline severe-drop audit passed. A5-C0 and A5-C4 ran with complete core logging; A5-C4 reproduced the known no-harm but non-improving A4 boundary for 40A -> 1A. No A5 improvement claim is made.

Baseline severe-drop audit passed. A5-T1/T2/T3/T4 may be prepared in the next task. No A5 improvement claim is made yet.

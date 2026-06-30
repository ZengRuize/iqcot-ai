# E010-A5-T4-R1 Research Summary

Date: 2026-06-30

## Result

`MODEL_REVISED`

R1 preserves the earlier T4proxy partial recovery reference, but the new burst-limited candidates fail the guard set. R1-T4a/b/c suppress positive peaks by driving severe undershoot/final-error collapse and still leave burst count above the limit.

## Candidate Table

| Variant | Success | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | REQ | Accepted | Dropped | Phase err | Final err mV | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R1-C0 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 149 | 149 | 0 | 0 | 2.97793 | carry_forward_reference |
| R1-C4 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 149 | 149 | 0 | 0 | 2.97793 | carry_forward_reference |
| R1-T4proxy | 1 | 4.06085 | 0.697797 | 3.55696 | 3.5337 | 149 | 149 | 0 | 0 | 2.96743 | carry_forward_reference |
| R1-T4a | 1 | 0 | 971.618 | 0 | 0 | 187 | 187 | 0 | 0 | -919.625 | positive_peak_suppressed_by_undershoot_guard_fail |
| R1-T4b | 1 | 0 | 971.618 | 0 | 0 | 187 | 187 | 0 | 0 | -919.625 | positive_peak_suppressed_by_undershoot_guard_fail |
| R1-T4c | 1 | 0 | 971.618 | 0 | 0 | 187 | 187 | 0 | 0 | -919.625 | positive_peak_suppressed_by_undershoot_guard_fail |

## Interpretation

Controlled reentry / burst limiting changed the waveform, but R1-T4a/b/c did not produce a usable recovery improvement. Their zero positive peaks are caused by severe undershoot/final-error collapse, and the burst count remains above the configured limit. A5 severe-drop recovery still needs reentry energy shaping rather than only pulse counting.

## Evidence Files

- Metrics: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/e010_a5_t4_r1_metrics.csv`
- Signal availability: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/e010_a5_t4_r1_signal_availability.csv`
- Scheduler audit: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/e010_a5_t4_r1_scheduler_audit.csv`

## Claim Boundary

Allowed only if classification is `MODEL_CONFIRMED`: a local derived-Simulink claim for the tested fixed-four-phase `40A -> 1A` case. Still forbidden: broad load-drop robustness, hardware/HIL/board/silicon validation, active Lambda control, active-phase shed during this severe drop, PIS-IEK first-peak prediction, universal threshold claims, AI direct gate control, or AI control of external load-current slew.

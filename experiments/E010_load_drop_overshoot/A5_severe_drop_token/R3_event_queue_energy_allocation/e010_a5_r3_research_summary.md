# E010-A5-R3 Research Summary

Date: 2026-07-01

## Result

`MODEL_REVISED`

R3 suppresses positive recovery peaks only by starving the recovery trajectory, producing severe undershoot/final-error collapse and failing burst/phase-order guards. Treat this as token-structure revision evidence, not as A5 validation.

| Variant | Success | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | Final err mV | Burst | Queue max/final | Deferred/Rejected/Dropped | Budget used ns | Guard | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R3-C0 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 2.97793 | NaN/NaN | NaN/NaN | 0/0/0 | NaN | 1 | REFERENCE |
| R3-C4 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 2.97793 | NaN/NaN | NaN/NaN | 0/0/0 | NaN | 1 | REFERENCE |
| R3-T4proxy | 1 | 4.06085 | 0.697797 | 3.55696 | 3.5337 | 2.96743 | 5/2 | NaN/NaN | 0/0/0 | NaN | 0 | MODEL_REVISED |
| R3-R2E1 | 1 | 3.51629 | 7.63188 | 1.75366 | 3.51629 | 2.89307 | 5/2 | NaN/NaN | 0/0/0 | 74.6 | 0 | MODEL_REVISED |
| R3-E1 | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0/0 | 0/0/0 | 60 | 0 | MODEL_REVISED |
| R3-E2 | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0/0 | 0/0/0 | 60 | 0 | MODEL_REVISED |
| R3-E3 | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0/0 | 0/0/0 | 60 | 0 | MODEL_REVISED |

## Evidence Files

- Metrics: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R3_event_queue_energy_allocation/e010_a5_r3_metrics.csv`
- Signal availability: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R3_event_queue_energy_allocation/e010_a5_r3_signal_availability.csv`
- Scheduler audit: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R3_event_queue_energy_allocation/e010_a5_r3_scheduler_audit.csv`

## Claim Boundary

If `MODEL_CONFIRMED`, the claim is limited to the local ideal IQCOT derived Simulink `40A -> 1A` severe-drop case. If revised, A5 remains blocked by reentry queue / energy-allocation guards. AI still does not command gates or external load-current slew.

Best partial variant: `none_safe_candidate`. R3-E1/E2/E3 share the same recovery-starvation failure mechanism, so no R3 candidate should be carried forward as a validated partial selector.

## Next Smallest Useful Step

Downgrade the severe-drop improvement claim or introduce a structurally different large-signal energy-management mechanism. Do not broaden to load grids, mismatch, active Lambda, active-phase shed, or the optional R3-E4 from this R3 state.

# E010-A5-R2 Research Summary

Date: 2026-07-01

## Result

`MODEL_REVISED`

R2-E1/E2 reduce the positive recovery peaks but violate the undershoot and burst guards. R2-E3/E4 suppress positive peaks only by scheduler-release starvation, reproducing the R1-like severe undershoot and final-error collapse. A5 remains MODEL_REVISED.

| Variant | Success | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | Final err mV | Burst | Dropped REQ | Phase err | Energy used ns | Guard | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R2-C0 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 2.97793 | NaN/NaN | 0 | NaN | NaN | 1 | REFERENCE |
| R2-C4 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 2.97793 | NaN/NaN | 0 | NaN | NaN | 1 | REFERENCE |
| R2-T4proxy | 1 | 4.06085 | 0.697797 | 3.55696 | 3.5337 | 2.96743 | 5/2 | 0 | NaN | NaN | 0 | MODEL_REVISED |
| R2-R1bad | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0 | NaN | NaN | 0 | MODEL_REVISED |
| R2-E1 | 1 | 3.51629 | 7.63188 | 1.75366 | 3.51629 | 2.89307 | 5/2 | 0 | 0 | 74.6 | 0 | MODEL_REVISED |
| R2-E2 | 1 | 3.51629 | 7.63188 | 1.75366 | 3.51629 | 2.89307 | 5/2 | 0 | 0 | 74.6 | 0 | MODEL_REVISED |
| R2-E3 | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0 | 0 | 74.6 | 0 | MODEL_REVISED |
| R2-E4 | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0 | 0 | 74.6 | 0 | MODEL_REVISED |

## Evidence Files

- Metrics: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/e010_a5_r2_metrics.csv`
- Signal availability: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/e010_a5_r2_signal_availability.csv`
- Scheduler audit: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/e010_a5_r2_scheduler_audit.csv`

## Claim Boundary

If `MODEL_CONFIRMED`, the claim is limited to the local ideal IQCOT derived Simulink `40A -> 1A` severe-drop case. If revised, A5 remains blocked by reentry energy-shaping or scheduler-release instability. AI still does not command gates or external load-current slew.

Best partial variant: `R2-E1`.

## Mechanism Interpretation

- `R2-E1`: energy budget plus Ton ramp reduces peak overshoot by `0.54456 mV` and recovery peak 2-12us by `1.85806 mV` versus C0/C4, but peak undershoot reaches `7.63188 mV` and burst count remains `5 / 2`.
- `R2-E2`: area-int soft preload is logged once but the waveform is numerically unchanged from E1, so the current soft-preload path is not a validated actuator.
- `R2-E3`: scheduler release gating creates `REQ_reject_count = 170` and collapses Vout to `971.618 mV` undershoot with final error `-919.625 mV`.
- `R2-E4`: voltage-window release is enabled, but the result remains identical to E3 on the hard guards; the failure is the release semantics/insertion point, not the absence of one scalar voltage-window flag.

## Next Smallest Useful Step

Revise the severe-drop `a_O` token structure itself: scheduler release must be an event-queue/energy-allocation policy that preserves recovery energy while enforcing burst and undershoot budgets. Do not broaden to load grids, mismatch, active Lambda, or active-phase shed from this R2 state.
